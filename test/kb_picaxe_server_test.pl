use strict;
use JSON;
use Data::Dumper;
use Test::More;
use Config::Simple;
use Time::HiRes qw(time);
use Bio::KBase::AuthToken;
#use Bio::KBase::workspace::Client;
use Workspace::WorkspaceClient;
use kb_pickaxe::kb_pickaxeImpl;

local $| = 1;
my $token = $ENV{'KB_AUTH_TOKEN'};
my $config_file = $ENV{'KB_DEPLOYMENT_CONFIG'};
my $config = new Config::Simple($config_file)->get_block('kb_pickaxe');
my $ws_url = $config->{"workspace-url"};
my $ws_name = undef;
#my $ws_client = new Bio::KBase::workspace::Client($ws_url,token => $token);
my $ws_client = Workspace::WorkspaceClient->new($ws_url,token => $token);
my $auth_token = Bio::KBase::AuthToken->new(token => $token, ignore_authrc => 1);
my $ctx = LocalCallContext->new($token, $auth_token->user_id);
$kb_pickaxe::kb_pickaxeServer::CallContext = $ctx;
my $impl = new kb_pickaxe::kb_pickaxeImpl();

sub get_ws_name {
    if (!defined($ws_name)) {
        my $suffix = int(time * 1000);
        $ws_name = 'test_kb_pickaxe_' . $suffix;
        $ws_client->create_workspace({workspace => $ws_name});
    }
    return $ws_name;
}

#=head
sub save_json_to_ws{
    my $filePath = shift;
    my $fileType = shift;
    print "Loading $filePath\n";
    my $Cjson;
    {
        local $/; #Enable 'slurp' mode
        open my $fh, "<", $filePath;
        $Cjson = <$fh>;
        close $fh;
    }
    my $data = decode_json($Cjson);
    my $ret = $ws_client->save_objects({
        workspace => get_ws_name(),
        objects   => [ {
            type => $fileType,
            name => $data->{name},
            data => $data
        } ]
    })->[0];

};
#=cut
save_json_to_ws("/kb/module/test/iMR1_799.json", "KBaseFBA.FBAModel");
save_json_to_ws("/kb/module/test/model_set.json", "KBaseBiochem.CompoundSet");
print("Data loaded\n");
eval {
    my $pickaxeParam = {
        workspace => get_ws_name(),
        model_id => "iMR1_799",
        out_model_id => "spont_out",
        rule_set => "spontaneous",
        generations => 1,
        prune=>'biochemistry',
    };
    my $ret =$impl->runpickaxe($pickaxeParam);
};
eval {
    my $pickaxeParam2 = {
        workspace => get_ws_name(),
        model_id => "model_set",
        out_model_id => "enz_out",
        rule_set => "enzymatic",
        generations => 1,
        prune=>'model'
    };
    my $ret2 =$impl->runpickaxe($pickaxeParam2);
};
my $err = undef;
if ($@) {
    $err = $@;
}
eval {
    if (defined($ws_name)) {
        $ws_client->delete_workspace({workspace => $ws_name});
        print("Test workspace was deleted\n");
    }
};
if (defined($err)) {
    if(ref($err) eq "Bio::KBase::Exceptions::KBaseException") {
        die("Error while running tests: " . $err->trace->as_string);
    } else {
        die $err;
    }
}

{
    package LocalCallContext;
    use strict;
    sub new {
        my($class,$token,$user) = @_;
        my $self = {
            token => $token,
            user_id => $user
        };
        return bless $self, $class;
    }
    sub user_id {
        my($self) = @_;
        return $self->{user_id};
    }
    sub token {
        my($self) = @_;
        return $self->{token};
    }
    sub provenance {
        my($self) = @_;
        return [{'service' => 'kb_pickaxe', 'method' => 'please_never_use_it_in_production', 'method_params' => []}];
    }
    sub authenticated {
        return 1;
    }
    sub log_debug {
        my($self,$msg) = @_;
        print STDERR $msg."\n";
    }
    sub log_info {
        my($self,$msg) = @_;
        print STDERR $msg."\n";
    }
}
