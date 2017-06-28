package kb_pickaxe::kb_pickaxeImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = '1.1.0';
our $GIT_URL = 'https://github.com/janakagithub/kb_pickaxe.git';
our $GIT_COMMIT_HASH = '8ea4643ff9d474d30c75fa3c2827b8fa4fc6f96d';

=head1 NAME

kb_pickaxe

=head1 DESCRIPTION

A KBase module: kb_Pickaxe
This method wraps the Pickaxe tool.

=cut

#BEGIN_HEADER
use Bio::KBase::AuthToken;
#use Bio::KBase::workspace::Client;
use Workspace::WorkspaceClient;
use Config::IniFiles;
use Data::Dumper;
use JSON;
use fba_tools::fba_toolsClient;
use FBAFileUtil::FBAFileUtilClient;

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    my $config_file = $ENV{ KB_DEPLOYMENT_CONFIG };
    my $cfg = Config::IniFiles->new(-file=>$config_file);
    my $wsInstance = $cfg->val('kb_pickaxe','workspace-url');
    die "no workspace-url defined" unless $wsInstance;

    $self->{'workspace-url'} = $wsInstance;

    print "Instantiating fba_tools\n";

    $self->{'callbackURL'} = $ENV{'SDK_CALLBACK_URL'};
    print "callbackURL is ", $self->{'callbackURL'}, "\n";


    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 runpickaxe

  $return = $obj->runpickaxe($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a kb_pickaxe.RunPickAxe
$return is a kb_pickaxe.PickAxeResults
RunPickAxe is a reference to a hash where the following keys are defined:
	workspace has a value which is a kb_pickaxe.workspace_name
	model_id has a value which is a kb_pickaxe.model_id
	model_ref has a value which is a string
	rule_set has a value which is a string
	generations has a value which is an int
	out_model_id has a value which is a kb_pickaxe.model_id
	compounds has a value which is a reference to a list where each element is a kb_pickaxe.EachCompound
workspace_name is a string
model_id is a string
EachCompound is a reference to a hash where the following keys are defined:
	compound_id has a value which is a string
	compound_name has a value which is a string
PickAxeResults is a reference to a hash where the following keys are defined:
	model_ref has a value which is a string

</pre>

=end html

=begin text

$params is a kb_pickaxe.RunPickAxe
$return is a kb_pickaxe.PickAxeResults
RunPickAxe is a reference to a hash where the following keys are defined:
	workspace has a value which is a kb_pickaxe.workspace_name
	model_id has a value which is a kb_pickaxe.model_id
	model_ref has a value which is a string
	rule_set has a value which is a string
	generations has a value which is an int
	out_model_id has a value which is a kb_pickaxe.model_id
	compounds has a value which is a reference to a list where each element is a kb_pickaxe.EachCompound
workspace_name is a string
model_id is a string
EachCompound is a reference to a hash where the following keys are defined:
	compound_id has a value which is a string
	compound_name has a value which is a string
PickAxeResults is a reference to a hash where the following keys are defined:
	model_ref has a value which is a string


=end text



=item Description



=back

=cut

sub runpickaxe
{
    my $self = shift;
    my($params) = @_;

    my @_bad_arguments;
    (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"params\" (value was \"$params\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to runpickaxe:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runpickaxe');
    }

    my $ctx = $kb_pickaxe::kb_pickaxeServer::CallContext;
    my($return);
    #BEGIN runpickaxe
    my $fbaO = new fba_tools::fba_toolsClient( $self->{'callbackURL'},
                                                            ( 'service_version' => 'dev',
                                                              'async_version' => 'dev',
                                                            )
                                                           );
=head
    my $ffu = new FBAFileUtil::FBAFileUtilClient( $self->{'callbackURL'},
                                                            ( 'service_version' => 'dev',
                                                              'async_version' => 'dev',
                                                            )
                                                          );
=cut

    my $Cjson;
    {
        local $/; #Enable 'slurp' mode
        open my $fh, "<", "/kb/module/data/Compounds.json";
        $Cjson = <$fh>;
        close $fh;
    }

    my $co = decode_json($Cjson);
    my $cpdStHash;
    for (my $i=0; $i< @{$co}; $i++){

        my $coId = $co->[$i]->{id};
        my $coStruc = $co->[$i]->{structure};
        my $coFormula = $co->[$i]->{formula};
        my $coName = $co->[$i]->{name};
        my $coAbbr = $co->[$i]->{abbreviation};
        my $coCharge =$co->[$i]->{charge};

        $cpdStHash->{$coId} = [$co->[$i]->{id},$co->[$i]->{structure},$co->[$i]->{formula},$co->[$i]->{name},$co->[$i]->{abbreviation},$co->[$i]->{charge}];
    }

    my $token=$ctx->token;
    #my $wshandle=Bio::KBase::workspace::Client->new($self->{'workspace-url'},token=>$token);
    my $wshandle=Workspace::WorkspaceClient->new($self->{'workspace-url'},token=>$token);

    open my $cpdListOut, ">", "/kb/module/work/tmp/inputModel.tsv"  or die "Couldn't open inputModel file $!\n";;;
    print $cpdListOut "id\tabbreviation\tname\tformula\tmass\tsource\tstructure\tcharge is_core\tis_obsolete\tlinked_compound\tis_cofactor\tdeltag\tdeltagerr\tpka\tpkb\tabstract_compound\tcomprised_of\taliases\n";


    print "loading model $params->{model_id}\n";

    #print "id\tabbreviation\tname\tformula\tmass\tsource\tstructure\tcharge is_core\tis_obsolete\tlinked_compound\tis_cofactor\tdeltag\tdeltagerr\tpka\tpkb\tabstract_compound\tcomprised_of\taliases\n";
    my $inputModelF = $wshandle->get_objects([{workspace=>$params->{workspace},name=>$params->{model_id}}])->[0];#{data}{modelcompounds};
    #my $inputModel = $wshandle->get_objects([{ref=>$params->{model_ref}}])->[0]{data}{modelcompounds};
    my $inputModel =  $inputModelF->{data}{modelcompounds};

    print "accessing input model $inputModelF->{id}\t genome_ref $inputModelF->{genome_ref}\n";
    print "Writing the compound input file for PickAxe\n\n";

    my $count =0;
    for (my $i=0; $i<@{$inputModel}; $i++){

        my @cpdId = split /_/, $inputModel->[$i]->{id};
        my $formula = $inputModel->[$i]->{formula};
        my $cpdName = $inputModel->[$i]->{name};

        if (defined $cpdStHash->{$cpdId[0]}->[1]){
        print $cpdListOut "$cpdId[0]\t$cpdStHash->{$cpdId[0]}->[4]\t$inputModel->[$i]->{name}\t $inputModel->[$i]->{formula}\t000\tModelSEED\t$cpdStHash->{$cpdId[0]}->[1]\n";
        #print  "$cpdId[0]\t$cpdStHash->{$cpdId[0]}->[4]\t$inputModel->[$i]->{name}\t $inputModel->[$i]->{formula}\t000\tModelSEED\t$cpdStHash->{$cpdId[0]}->[1]\n";
        $count++;
        }

    }
    print "$count lines of compounds data will be prepaired for Pickaxe execution, continuing.....\n";

    close $cpdListOut;
    print "$params->{generations} gen $params->{rule_set}\n";
    print "Running Pickaxe\n";
    my $gen = $params->{generations};

    if ($params->{rule_set} eq 'spontaneous') {
        system ("python3 /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/pickaxe.py -C /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/ChemicalDamageCoreactants.tsv -r /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/ChemicalDamageReactionRules.tsv -g $gen -c /kb/module/work/tmp/inputModel.tsv -o /kb/module/work/tmp");
    } elsif ($params->{rule_set} eq 'enzymatic') {
        print "meh";
        system ("python3 /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/pickaxe.py -C /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/EnzymaticCoreactants.tsv -r /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/EnzymaticReactionRules.tsv --bnice -g $gen -c /kb/module/work/tmp/inputModel.tsv -o /kb/module/work/tmp");
    } else{
        die "Invalid reaction rule set";
    }

    #print &Dumper ($fm);

    open my $fhc, "<", "/kb/module/work/tmp/compounds.tsv" or die "Couldn't open compounds file $!\n";
    open my $fhr, "<", "/kb/module/work/tmp/reactions.tsv" or die "Couldn't open reactions file $!\n";

    open my $mcf, ">", "/kb/module/work/tmp/FBAModelCompounds.tsv"  or die "Couldn't open FBAModelCompounds file $!\n";
    open my $mcr, ">", "/kb/module/work/tmp/FBAModelReactions.tsv"  or die "Couldn't open FBAModelCompounds file $!\n";;;



    print $mcf "id\tname\tformula\tcharge\taliases\n";
    <$fhc>;
    while (my $input = <$fhc>){
        chomp $input;
        my @cpdId = split /\t/, $input;
        if (defined $cpdStHash->{$cpdId[0]}){

            print $mcf "$cpdId[0]\t$cpdStHash->{$cpdId[0]}->[3]\t$cpdStHash->{$cpdId[0]}->[2]\t$cpdStHash->{$cpdId[0]}->[5]\tnone\n"
        }
        else {

            print $mcf "$cpdId[0]\t$cpdId[0]\tnone\t0\tnone\n";
        }


    }
    close $mcf;
    close $fhc;

    print $mcr "id\tdirection\tcompartment\tgpr\tname\tenzyme\tpathway\treference\tequation\n";
    <$fhr>;
    my $count =0;
    while (my $input = <$fhr>){
        chomp $input;
        my @rxnId = split /\t/, $input;
        #my $rxneq = s/=/-/g, $rxnId[2];
            print $mcr "$rxnId[0]\t>\tc0\tnone\t$rxnId[0]\tnone\tnone\tnone\t$rxnId[2]\n";
        if ($count == 4000){

            #last;
        }
        $count++;
    }

    close $mcr;
    close $fhr;

    my $rxnFile = {
        path => "/kb/module/work/tmp/FBAModelReactions.tsv"
    };

    my $cpdFile = {
        path => "/kb/module/work/tmp/FBAModelCompounds.tsv"
    };

    my $tsvToModel = {

        model_name => $params->{out_model_id},
        workspace_name =>$params->{workspace},
        #genome => "none",
        biomass => [],
        model_file => $rxnFile,
        compounds_file => $cpdFile
    };

    my $ffuRef = $fbaO->tsv_file_to_model($tsvToModel);

    print &Dumper ($ffuRef);

    my $returnVar = {
        model_ref => $ffuRef->{ref}
    };

    print &Dumper ($returnVar);

    return $returnVar;

    #END runpickaxe
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to runpickaxe:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'runpickaxe');
    }
    return($return);
}




=head2 status 

  $return = $obj->status()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module status. This is a structure including Semantic Versioning number, state and git info.

=back

=cut

sub status {
    my($return);
    #BEGIN_STATUS
    $return = {"state" => "OK", "message" => "", "version" => $VERSION,
               "git_url" => $GIT_URL, "git_commit_hash" => $GIT_COMMIT_HASH};
    #END_STATUS
    return($return);
}

=head1 TYPES



=head2 model_id

=over 4



=item Description

A string representing a model id.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 workspace_name

=over 4



=item Description

A string representing a workspace name.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 EachCompound

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compound_id has a value which is a string
compound_name has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compound_id has a value which is a string
compound_name has a value which is a string


=end text

=back



=head2 RunPickAxe

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a kb_pickaxe.workspace_name
model_id has a value which is a kb_pickaxe.model_id
model_ref has a value which is a string
rule_set has a value which is a string
generations has a value which is an int
out_model_id has a value which is a kb_pickaxe.model_id
compounds has a value which is a reference to a list where each element is a kb_pickaxe.EachCompound

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a kb_pickaxe.workspace_name
model_id has a value which is a kb_pickaxe.model_id
model_ref has a value which is a string
rule_set has a value which is a string
generations has a value which is an int
out_model_id has a value which is a kb_pickaxe.model_id
compounds has a value which is a reference to a list where each element is a kb_pickaxe.EachCompound


=end text

=back



=head2 PickAxeResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model_ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_ref has a value which is a string


=end text

=back



=cut

1;
