package kb_pickaxe::kb_pickaxeImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org
our $VERSION = '1.3.0';
our $GIT_URL = 'git@github.com:kbaseapps/kb_pickaxe.git';
our $GIT_COMMIT_HASH = '0051b19e4cda0caf5f844bccf6d46e07f0b069b9';

=head1 NAME

kb_pickaxe

=head1 DESCRIPTION

A KBase module: kb_picaxe
This method wraps the PicAxe tool.

=cut

#BEGIN_HEADER
use Bio::KBase::AuthToken;
#use Bio::KBase::workspace::Client;
use Workspace::WorkspaceClient;
use Config::IniFiles;
use Data::Dumper;
use JSON;
use fba_tools::fba_toolsClient;

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
	prune has a value which is a string
	add_transport has a value which is an int
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
	prune has a value which is a string
	add_transport has a value which is an int
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
    sub make_tsv_from_model {
        my $co = shift;
        my $cpdStHash = shift;
        my $inputModelF = shift;
        my $inputModel =  $inputModelF->{data}{modelcompounds};

        open my $cpdListOut, ">", "/kb/module/work/tmp/inputModel.tsv"  or die "Couldn't open inputModel file $!\n";;;
        print $cpdListOut "id\t\structure\n";

        print "accessing input model $inputModelF->{id}\t genome_ref $inputModelF->{genome_ref}\n";
        print "Writing the compound input file for Pickaxe\n\n";

        my $count =0;
        for (my $i=0; $i<@{$inputModel}; $i++){
            my @cpdId = split /_/, $inputModel->[$i]->{id};
            my $altID = $inputModel->[$i]->{dblinks}->{'ModelSeed'}[0];
            if (defined $inputModel->[$i]->{smiles}){
                print $cpdListOut "$inputModel->[$i]->{id}\t$inputModel->[$i]->{smiles}\n";
                $count++;
            }
            elsif (defined $cpdStHash->{$cpdId[0]}){
                print $cpdListOut "$cpdId[0]\t$co->[$cpdStHash->{$cpdId[0]}]->{structure}\n";
                $count++;
            }
            elsif (defined $cpdStHash->{$altID}){
                print $cpdListOut "$altID\t$co->[$cpdStHash->{$altID}]->{structure}\n";
                $count++;
            }

        }
        print "$count lines of compounds data will be prepaired for Pickaxe execution, continuing.....\n";

        close $cpdListOut;
    }
    sub make_tsv_from_compoundset{
        my $compoundset = shift;
        print "Writeing Pickaxe input file from compound set\n";
        open my $cpdListOut, ">", "/kb/module/work/tmp/inputModel.tsv"  or die "Couldn't open inputModel file $!\n";;;
        print $cpdListOut "id\t\structure\n";
        for (my $i=0; $i<@{$compoundset}; $i++){
            print $cpdListOut "$compoundset->[$i]->{id}\t$compoundset->[$i]->{smiles}\n"
        }

    }
    my $fbaO = new fba_tools::fba_toolsClient( $self->{'callbackURL'},
        ('service_version' => 'beta', 'async_version' => 'beta',)
    );
    my $Cjson;
    {
        local $/; #Enable 'slurp' mode
        open my $fh, "<", "/kb/module/data/Compounds.json";
        $Cjson = <$fh>;
        close $fh;
    }

    my $co = decode_json($Cjson);
    my $cpdStHash;
    my $inchikeyHash;
    for (my $i=0; $i< @{$co}; $i++){
        my $coInchikey = $co->[$i]->{inchikey};
        $cpdStHash->{$co->[$i]->{id}} = $i;
        if ($coInchikey){
            $inchikeyHash->{$coInchikey} = $i
        }
    }
    my $token=$ctx->token;
    my $wshandle=Workspace::WorkspaceClient->new($self->{'workspace-url'},token=>$token);

    print "loading $params->{model_id}\n";
    my $inputModelF = $wshandle->get_objects([{workspace=>$params->{workspace},name=>$params->{model_id}}])->[0];

    if (index($inputModelF->{info}[2], 'KBaseFBA.FBAModel') != -1) {
        make_tsv_from_model($co, $cpdStHash, $inputModelF);
    }
    else {
        make_tsv_from_compoundset($inputModelF->{data}{compounds})
    }
    print "$params->{generations} gen $params->{rule_set}\n";
    #print "Testing Pickaxe execution first....\n";

    #system ('python3 /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/pickaxe.py -h');
    print "Now running Pickaxe\n";

    my $gen = $params->{generations};
    my $command = "python3 /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/pickaxe.py -g $gen -c /kb/module/work/tmp/inputModel.tsv -o /kb/module/work/tmp";
    my $coreactant_path = "/kb/module/data/NoCoreactants.tsv";
    my $retro_rule_path = "/kb/module/data/".$params->{rule_set}.".tsv --bnice -q -m 4";

    if ($params->{rule_set} eq 'spontaneous') {
        print "generating novel compounds based on spontanios reaction rules for $gen generations\n";
        $command .= ' -C /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/ChemicalDamageCoreactants.tsv -r /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/ChemicalDamageReactionRules.tsv';

    } elsif ($params->{rule_set} eq 'enzymatic') {
        print "generating novel compounds based on enzymatic reaction rules for $gen generations\n";
        $command .= ' -C /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/EnzymaticCoreactants.tsv -r /kb/dev_container/modules/Pickaxe/MINE-Database/minedatabase/data/EnzymaticReactionRules.tsv --bnice';

    } elsif ($params->{rule_set} =~ /retro_rules/) {
        print "generating novel compounds based on $params->{rule_set} reaction rules for $gen generations\n";
        $command .= " -C $coreactant_path -r $retro_rule_path";

    } else {
        die "Invalid reaction rule set or rule set not defined";
    }

    if ($params->{prune} eq 'model') {
        $command .= ' -p /kb/module/work/tmp/inputModel.tsv';

    } elsif ($params->{prune} eq 'biochemistry') {
        $command .= ' -p /kb/module/data/Compounds.json';
    }

    system($command);


    open my $fhc, "<", "/kb/module/work/tmp/compounds.tsv" or die "Couldn't open compounds file $!\n";
    open my $fhr, "<", "/kb/module/work/tmp/reactions.tsv" or die "Couldn't open reactions file $!\n";

    open my $mcf, ">", "/kb/module/work/tmp/FBAModelCompounds.tsv"  or die "Couldn't open FBAModelCompounds file $!\n";
    open my $mcr, ">", "/kb/module/work/tmp/FBAModelReactions.tsv"  or die "Couldn't open FBAModelCompounds file $!\n";;;

    print $mcf "id\tname\tformula\tcharge\taliases\tinchikey\tsmiles\n";
    <$fhc>;
    while (my $input = <$fhc>){
        chomp $input;
        my @cpdData = split /\t/, $input;
        # KBase doesn't use charges in formulas so strip these
        $cpdData[3] =~ s/(\+|-)\d*$//;
        if (defined $cpdStHash->{$cpdData[0]}){
            my $seedcmp = $co->[$cpdStHash->{$cpdData[0]}];
            print $mcf "$cpdData[0]_c0\t$seedcmp->{name}\t$seedcmp->{formula}\t$seedcmp->{charge}\tnone\t$cpdData[5]\t$cpdData[6]\n";
        } elsif (defined $inchikeyHash->{$cpdData[5]}){
            my $seedcmp = $co->[$inchikeyHash->{$cpdData[5]}];
            print $mcf "$cpdData[0]_c0\t$seedcmp->{name}\t$seedcmp->{formula}\t$seedcmp->{charge}\tnone\t$cpdData[5]\t$cpdData[6]\n";
        } else {
            print $mcf "$cpdData[0]_c0\t$cpdData[0]\t$cpdData[3]\t$cpdData[4]\tnone\t$cpdData[5]\t$cpdData[6]\n";
        }
    }
    close $fhc;

    print $mcr "id\tdirection\tcompartment\tgpr\tname\tenzyme\tpathway\treference\tequation\n";
    <$fhr>;
    while (my $input = <$fhr>){
        chomp $input;
        my @rxnId = split /\t/, $input;
        print $mcr "$rxnId[0]\t>\tc0\tnone\t$rxnId[0]\tnone\tnone\t$rxnId[5]\t$rxnId[2]\n";
    }

    if ($params->{add_transport}){
        print("Adding Transport reactions\n");
        my @compounds;
        if (exists $inputModelF->{data}{compounds}) {
            @compounds = @{$inputModelF->{data}{compounds}};
        } elsif (exists $inputModelF->{data}{modelcompounds}) {
            @compounds = @{$inputModelF->{data}{modelcompounds}}
        }
        my %compound_set;
        foreach my $compound (@compounds) {
            my $cid = $compound->{id};
            $cid = (split /_/, $cid)[0];
            if (!exists $compound_set{$cid}) {
                $compound_set{$cid}++;
                print $mcf $cid."_c0\tnone\tnone\t0\tnone\tnone\tnone\n";
                print $mcf $cid."_e0\tnone\tnone\t0\tnone\tnone\tnone\n";
                print $mcr "$cid transporter\t>\tc0\tnone\t$cid transporter\tnone\tnone\tnone\t(1) $cid" . "_e0 => (1) $cid" . "_c0\n";
            }
        }
    }

    close $mcr;
    close $mcf;
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
prune has a value which is a string
add_transport has a value which is an int
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
prune has a value which is a string
add_transport has a value which is an int
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
