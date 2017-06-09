package FBAFileUtil::FBAFileUtilClient;

use JSON::RPC::Client;
use POSIX;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
use Time::HiRes;
my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};

use Bio::KBase::AuthToken;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

FBAFileUtil::FBAFileUtilClient

=head1 DESCRIPTION





=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => FBAFileUtil::FBAFileUtilClient::RpcClient->new,
	url => $url,
	headers => [],
    };
    my %arg_hash = @args;
    $self->{async_job_check_time} = 0.1;
    if (exists $arg_hash{"async_job_check_time_ms"}) {
        $self->{async_job_check_time} = $arg_hash{"async_job_check_time_ms"} / 1000.0;
    }
    $self->{async_job_check_time_scale_percent} = 150;
    if (exists $arg_hash{"async_job_check_time_scale_percent"}) {
        $self->{async_job_check_time_scale_percent} = $arg_hash{"async_job_check_time_scale_percent"};
    }
    $self->{async_job_check_max_time} = 300;  # 5 minutes
    if (exists $arg_hash{"async_job_check_max_time_ms"}) {
        $self->{async_job_check_max_time} = $arg_hash{"async_job_check_max_time_ms"} / 1000.0;
    }
    my $service_version = 'release';
    if (exists $arg_hash{"service_version"}) {
        $service_version = $arg_hash{"service_version"};
    }
    $self->{service_version} = $service_version;

    chomp($self->{hostname} = `hostname`);
    $self->{hostname} ||= 'unknown-host';

    #
    # Set up for propagating KBRPC_TAG and KBRPC_METADATA environment variables through
    # to invoked services. If these values are not set, we create a new tag
    # and a metadata field with basic information about the invoking script.
    #
    if ($ENV{KBRPC_TAG})
    {
	$self->{kbrpc_tag} = $ENV{KBRPC_TAG};
    }
    else
    {
	my ($t, $us) = &$get_time();
	$us = sprintf("%06d", $us);
	my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	$self->{kbrpc_tag} = "C:$0:$self->{hostname}:$$:$ts";
    }
    push(@{$self->{headers}}, 'Kbrpc-Tag', $self->{kbrpc_tag});

    if ($ENV{KBRPC_METADATA})
    {
	$self->{kbrpc_metadata} = $ENV{KBRPC_METADATA};
	push(@{$self->{headers}}, 'Kbrpc-Metadata', $self->{kbrpc_metadata});
    }

    if ($ENV{KBRPC_ERROR_DEST})
    {
	$self->{kbrpc_error_dest} = $ENV{KBRPC_ERROR_DEST};
	push(@{$self->{headers}}, 'Kbrpc-Errordest', $self->{kbrpc_error_dest});
    }

    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.

    {
	my $token = Bio::KBase::AuthToken->new(@args);
	
	if (!$token->error_message)
	{
	    $self->{token} = $token->token;
	    $self->{client}->{token} = $token->token;
	}
        else
        {
	    #
	    # All methods in this module require authentication. In this case, if we
	    # don't have a token, we can't continue.
	    #
	    die "Authentication failed: " . $token->error_message;
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}

sub _check_job {
    my($self, @args) = @_;
# Authentication: ${method.authentication}
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _check_job (received $n, expecting 1)");
    }
    {
        my($job_id) = @args;
        my @_bad_arguments;
        (!ref($job_id)) or push(@_bad_arguments, "Invalid type for argument 0 \"job_id\" (it should be a string)");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _check_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_check_job');
        }
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._check_job",
        params => \@args});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_check_job',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
                          );
        } else {
            return $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _check_job",
                        status_line => $self->{client}->status_line,
                        method_name => '_check_job');
    }
}




=head2 excel_file_to_model

  $return = $obj->excel_file_to_model($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub excel_file_to_model
{
    my($self, @args) = @_;
    my $job_id = $self->_excel_file_to_model_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _excel_file_to_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _excel_file_to_model_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _excel_file_to_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_excel_file_to_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._excel_file_to_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_excel_file_to_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _excel_file_to_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_excel_file_to_model_submit');
    }
}

 


=head2 sbml_file_to_model

  $return = $obj->sbml_file_to_model($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub sbml_file_to_model
{
    my($self, @args) = @_;
    my $job_id = $self->_sbml_file_to_model_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _sbml_file_to_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _sbml_file_to_model_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _sbml_file_to_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_sbml_file_to_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._sbml_file_to_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_sbml_file_to_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _sbml_file_to_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_sbml_file_to_model_submit');
    }
}

 


=head2 tsv_file_to_model

  $return = $obj->tsv_file_to_model($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.ModelCreationParams
$return is a FBAFileUtil.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a FBAFileUtil.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub tsv_file_to_model
{
    my($self, @args) = @_;
    my $job_id = $self->_tsv_file_to_model_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _tsv_file_to_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _tsv_file_to_model_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _tsv_file_to_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_tsv_file_to_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._tsv_file_to_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_tsv_file_to_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _tsv_file_to_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_tsv_file_to_model_submit');
    }
}

 


=head2 model_to_excel_file

  $f = $obj->model_to_excel_file($model)

=over 4

=item Parameter and return types

=begin html

<pre>
$model is a FBAFileUtil.ModelObjectSelectionParams
$f is a FBAFileUtil.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a FBAFileUtil.ModelObjectSelectionParams
$f is a FBAFileUtil.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub model_to_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_model_to_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _model_to_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _model_to_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($model) = @args;
        my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _model_to_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_model_to_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._model_to_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_model_to_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _model_to_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_model_to_excel_file_submit');
    }
}

 


=head2 model_to_sbml_file

  $f = $obj->model_to_sbml_file($model)

=over 4

=item Parameter and return types

=begin html

<pre>
$model is a FBAFileUtil.ModelObjectSelectionParams
$f is a FBAFileUtil.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a FBAFileUtil.ModelObjectSelectionParams
$f is a FBAFileUtil.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub model_to_sbml_file
{
    my($self, @args) = @_;
    my $job_id = $self->_model_to_sbml_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _model_to_sbml_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _model_to_sbml_file_submit (received $n, expecting 1)");
    }
    {
        my($model) = @args;
        my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _model_to_sbml_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_model_to_sbml_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._model_to_sbml_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_model_to_sbml_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _model_to_sbml_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_model_to_sbml_file_submit');
    }
}

 


=head2 model_to_tsv_file

  $files = $obj->model_to_tsv_file($model)

=over 4

=item Parameter and return types

=begin html

<pre>
$model is a FBAFileUtil.ModelObjectSelectionParams
$files is a FBAFileUtil.ModelTsvFiles
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
ModelTsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a FBAFileUtil.File
	reactions_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a FBAFileUtil.ModelObjectSelectionParams
$files is a FBAFileUtil.ModelTsvFiles
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
ModelTsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a FBAFileUtil.File
	reactions_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub model_to_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_model_to_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _model_to_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _model_to_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($model) = @args;
        my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _model_to_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_model_to_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._model_to_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_model_to_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _model_to_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_model_to_tsv_file_submit');
    }
}

 


=head2 export_model_as_excel_file

  $output = $obj->export_model_as_excel_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_model_as_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_model_as_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_model_as_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_model_as_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_model_as_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_model_as_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_model_as_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_model_as_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_model_as_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_model_as_excel_file_submit');
    }
}

 


=head2 export_model_as_tsv_file

  $output = $obj->export_model_as_tsv_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_model_as_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_model_as_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_model_as_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_model_as_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_model_as_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_model_as_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_model_as_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_model_as_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_model_as_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_model_as_tsv_file_submit');
    }
}

 


=head2 export_model_as_sbml_file

  $output = $obj->export_model_as_sbml_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_model_as_sbml_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_model_as_sbml_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_model_as_sbml_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_model_as_sbml_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_model_as_sbml_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_model_as_sbml_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_model_as_sbml_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_model_as_sbml_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_model_as_sbml_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_model_as_sbml_file_submit');
    }
}

 


=head2 fba_to_excel_file

  $f = $obj->fba_to_excel_file($fba)

=over 4

=item Parameter and return types

=begin html

<pre>
$fba is a FBAFileUtil.FBAObjectSelectionParams
$f is a FBAFileUtil.File
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$fba is a FBAFileUtil.FBAObjectSelectionParams
$f is a FBAFileUtil.File
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub fba_to_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_fba_to_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _fba_to_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _fba_to_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($fba) = @args;
        my @_bad_arguments;
        (ref($fba) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"fba\" (value was \"$fba\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _fba_to_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_fba_to_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._fba_to_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_fba_to_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _fba_to_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_fba_to_excel_file_submit');
    }
}

 


=head2 fba_to_tsv_file

  $files = $obj->fba_to_tsv_file($fba)

=over 4

=item Parameter and return types

=begin html

<pre>
$fba is a FBAFileUtil.FBAObjectSelectionParams
$files is a FBAFileUtil.FBATsvFiles
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
FBATsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a FBAFileUtil.File
	reactions_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$fba is a FBAFileUtil.FBAObjectSelectionParams
$files is a FBAFileUtil.FBATsvFiles
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
FBATsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a FBAFileUtil.File
	reactions_file has a value which is a FBAFileUtil.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub fba_to_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_fba_to_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _fba_to_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _fba_to_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($fba) = @args;
        my @_bad_arguments;
        (ref($fba) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"fba\" (value was \"$fba\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _fba_to_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_fba_to_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._fba_to_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_fba_to_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _fba_to_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_fba_to_tsv_file_submit');
    }
}

 


=head2 export_fba_as_excel_file

  $output = $obj->export_fba_as_excel_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_fba_as_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_fba_as_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_fba_as_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_fba_as_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_fba_as_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_fba_as_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_fba_as_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_fba_as_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_fba_as_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_fba_as_excel_file_submit');
    }
}

 


=head2 export_fba_as_tsv_file

  $output = $obj->export_fba_as_tsv_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_fba_as_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_fba_as_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_fba_as_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_fba_as_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_fba_as_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_fba_as_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_fba_as_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_fba_as_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_fba_as_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_fba_as_tsv_file_submit');
    }
}

 


=head2 tsv_file_to_media

  $return = $obj->tsv_file_to_media($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.MediaCreationParams
$return is a FBAFileUtil.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a FBAFileUtil.File
	media_name has a value which is a string
	workspace_name has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.MediaCreationParams
$return is a FBAFileUtil.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a FBAFileUtil.File
	media_name has a value which is a string
	workspace_name has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub tsv_file_to_media
{
    my($self, @args) = @_;
    my $job_id = $self->_tsv_file_to_media_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _tsv_file_to_media_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _tsv_file_to_media_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _tsv_file_to_media_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_tsv_file_to_media_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._tsv_file_to_media_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_tsv_file_to_media_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _tsv_file_to_media_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_tsv_file_to_media_submit');
    }
}

 


=head2 excel_file_to_media

  $return = $obj->excel_file_to_media($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.MediaCreationParams
$return is a FBAFileUtil.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a FBAFileUtil.File
	media_name has a value which is a string
	workspace_name has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.MediaCreationParams
$return is a FBAFileUtil.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a FBAFileUtil.File
	media_name has a value which is a string
	workspace_name has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub excel_file_to_media
{
    my($self, @args) = @_;
    my $job_id = $self->_excel_file_to_media_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _excel_file_to_media_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _excel_file_to_media_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _excel_file_to_media_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_excel_file_to_media_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._excel_file_to_media_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_excel_file_to_media_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _excel_file_to_media_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_excel_file_to_media_submit');
    }
}

 


=head2 media_to_tsv_file

  $f = $obj->media_to_tsv_file($media)

=over 4

=item Parameter and return types

=begin html

<pre>
$media is a FBAFileUtil.MediaObjectSelectionParams
$f is a FBAFileUtil.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$media is a FBAFileUtil.MediaObjectSelectionParams
$f is a FBAFileUtil.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub media_to_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_media_to_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _media_to_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _media_to_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($media) = @args;
        my @_bad_arguments;
        (ref($media) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"media\" (value was \"$media\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _media_to_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_media_to_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._media_to_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_media_to_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _media_to_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_media_to_tsv_file_submit');
    }
}

 


=head2 media_to_excel_file

  $f = $obj->media_to_excel_file($media)

=over 4

=item Parameter and return types

=begin html

<pre>
$media is a FBAFileUtil.MediaObjectSelectionParams
$f is a FBAFileUtil.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$media is a FBAFileUtil.MediaObjectSelectionParams
$f is a FBAFileUtil.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub media_to_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_media_to_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _media_to_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _media_to_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($media) = @args;
        my @_bad_arguments;
        (ref($media) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"media\" (value was \"$media\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _media_to_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_media_to_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._media_to_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_media_to_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _media_to_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_media_to_excel_file_submit');
    }
}

 


=head2 export_media_as_excel_file

  $output = $obj->export_media_as_excel_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_media_as_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_media_as_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_media_as_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_media_as_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_media_as_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_media_as_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_media_as_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_media_as_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_media_as_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_media_as_excel_file_submit');
    }
}

 


=head2 export_media_as_tsv_file

  $output = $obj->export_media_as_tsv_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_media_as_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_media_as_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_media_as_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_media_as_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_media_as_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_media_as_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_media_as_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_media_as_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_media_as_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_media_as_tsv_file_submit');
    }
}

 


=head2 tsv_file_to_phenotype_set

  $return = $obj->tsv_file_to_phenotype_set($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a FBAFileUtil.PhenotypeSetCreationParams
$return is a FBAFileUtil.WorkspaceRef
PhenotypeSetCreationParams is a reference to a hash where the following keys are defined:
	phenotype_set_file has a value which is a FBAFileUtil.File
	phenotype_set_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a FBAFileUtil.PhenotypeSetCreationParams
$return is a FBAFileUtil.WorkspaceRef
PhenotypeSetCreationParams is a reference to a hash where the following keys are defined:
	phenotype_set_file has a value which is a FBAFileUtil.File
	phenotype_set_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string


=end text

=item Description



=back

=cut

sub tsv_file_to_phenotype_set
{
    my($self, @args) = @_;
    my $job_id = $self->_tsv_file_to_phenotype_set_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _tsv_file_to_phenotype_set_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _tsv_file_to_phenotype_set_submit (received $n, expecting 1)");
    }
    {
        my($p) = @args;
        my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _tsv_file_to_phenotype_set_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_tsv_file_to_phenotype_set_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._tsv_file_to_phenotype_set_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_tsv_file_to_phenotype_set_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _tsv_file_to_phenotype_set_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_tsv_file_to_phenotype_set_submit');
    }
}

 


=head2 phenotype_set_to_tsv_file

  $f = $obj->phenotype_set_to_tsv_file($phenotype_set)

=over 4

=item Parameter and return types

=begin html

<pre>
$phenotype_set is a FBAFileUtil.PhenotypeSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$phenotype_set is a FBAFileUtil.PhenotypeSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub phenotype_set_to_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_phenotype_set_to_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _phenotype_set_to_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _phenotype_set_to_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($phenotype_set) = @args;
        my @_bad_arguments;
        (ref($phenotype_set) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"phenotype_set\" (value was \"$phenotype_set\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _phenotype_set_to_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_phenotype_set_to_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._phenotype_set_to_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_phenotype_set_to_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _phenotype_set_to_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_phenotype_set_to_tsv_file_submit');
    }
}

 


=head2 export_phenotype_set_as_tsv_file

  $output = $obj->export_phenotype_set_as_tsv_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_phenotype_set_as_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_phenotype_set_as_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_phenotype_set_as_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_phenotype_set_as_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_phenotype_set_as_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_phenotype_set_as_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_phenotype_set_as_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_phenotype_set_as_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_phenotype_set_as_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_phenotype_set_as_tsv_file_submit');
    }
}

 


=head2 phenotype_simulation_set_to_excel_file

  $f = $obj->phenotype_simulation_set_to_excel_file($pss)

=over 4

=item Parameter and return types

=begin html

<pre>
$pss is a FBAFileUtil.PhenotypeSimulationSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$pss is a FBAFileUtil.PhenotypeSimulationSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub phenotype_simulation_set_to_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_phenotype_simulation_set_to_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _phenotype_simulation_set_to_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _phenotype_simulation_set_to_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($pss) = @args;
        my @_bad_arguments;
        (ref($pss) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"pss\" (value was \"$pss\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _phenotype_simulation_set_to_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_phenotype_simulation_set_to_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._phenotype_simulation_set_to_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_phenotype_simulation_set_to_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _phenotype_simulation_set_to_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_phenotype_simulation_set_to_excel_file_submit');
    }
}

 


=head2 phenotype_simulation_set_to_tsv_file

  $f = $obj->phenotype_simulation_set_to_tsv_file($pss)

=over 4

=item Parameter and return types

=begin html

<pre>
$pss is a FBAFileUtil.PhenotypeSimulationSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$pss is a FBAFileUtil.PhenotypeSimulationSetObjectSelectionParams
$f is a FBAFileUtil.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a FBAFileUtil.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub phenotype_simulation_set_to_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_phenotype_simulation_set_to_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _phenotype_simulation_set_to_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _phenotype_simulation_set_to_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($pss) = @args;
        my @_bad_arguments;
        (ref($pss) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"pss\" (value was \"$pss\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _phenotype_simulation_set_to_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_phenotype_simulation_set_to_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._phenotype_simulation_set_to_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_phenotype_simulation_set_to_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _phenotype_simulation_set_to_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_phenotype_simulation_set_to_tsv_file_submit');
    }
}

 


=head2 export_phenotype_simulation_set_as_excel_file

  $output = $obj->export_phenotype_simulation_set_as_excel_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_phenotype_simulation_set_as_excel_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_phenotype_simulation_set_as_excel_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_phenotype_simulation_set_as_excel_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_phenotype_simulation_set_as_excel_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_phenotype_simulation_set_as_excel_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_phenotype_simulation_set_as_excel_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_phenotype_simulation_set_as_excel_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_phenotype_simulation_set_as_excel_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_phenotype_simulation_set_as_excel_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_phenotype_simulation_set_as_excel_file_submit');
    }
}

 


=head2 export_phenotype_simulation_set_as_tsv_file

  $output = $obj->export_phenotype_simulation_set_as_tsv_file($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a FBAFileUtil.ExportParams
$output is a FBAFileUtil.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub export_phenotype_simulation_set_as_tsv_file
{
    my($self, @args) = @_;
    my $job_id = $self->_export_phenotype_simulation_set_as_tsv_file_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _export_phenotype_simulation_set_as_tsv_file_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _export_phenotype_simulation_set_as_tsv_file_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _export_phenotype_simulation_set_as_tsv_file_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_export_phenotype_simulation_set_as_tsv_file_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._export_phenotype_simulation_set_as_tsv_file_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_export_phenotype_simulation_set_as_tsv_file_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _export_phenotype_simulation_set_as_tsv_file_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_export_phenotype_simulation_set_as_tsv_file_submit');
    }
}

 
 
sub status
{
    my($self, @args) = @_;
    my $job_id = undef;
    if ((my $n = @args) != 0) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function status (received $n, expecting 0)");
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil._status_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_status_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            $job_id = $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _status_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_status_submit');
    }
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}
   

sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "FBAFileUtil.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'export_phenotype_simulation_set_as_tsv_file',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method export_phenotype_simulation_set_as_tsv_file",
            status_line => $self->{client}->status_line,
            method_name => 'export_phenotype_simulation_set_as_tsv_file',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for FBAFileUtil::FBAFileUtilClient\n";
    }
    if ($sMajor == 0) {
        warn "FBAFileUtil::FBAFileUtilClient version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 boolean

=over 4



=item Description

A boolean - 0 for false, 1 for true.
@range (0, 1)


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 File

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
path has a value which is a string
shock_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
path has a value which is a string
shock_id has a value which is a string


=end text

=back



=head2 WorkspaceRef

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ref has a value which is a string


=end text

=back



=head2 ExportParams

=over 4



=item Description

input and output structure functions for standard downloaders


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
input_ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
input_ref has a value which is a string


=end text

=back



=head2 ExportOutput

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
shock_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
shock_id has a value which is a string


=end text

=back



=head2 ModelCreationParams

=over 4



=item Description

compounds_file is not used for excel file creations


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model_file has a value which is a FBAFileUtil.File
model_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string
biomass has a value which is a reference to a list where each element is a string
compounds_file has a value which is a FBAFileUtil.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_file has a value which is a FBAFileUtil.File
model_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string
biomass has a value which is a reference to a list where each element is a string
compounds_file has a value which is a FBAFileUtil.File


=end text

=back



=head2 ModelObjectSelectionParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
model_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
model_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean


=end text

=back



=head2 ModelTsvFiles

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compounds_file has a value which is a FBAFileUtil.File
reactions_file has a value which is a FBAFileUtil.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compounds_file has a value which is a FBAFileUtil.File
reactions_file has a value which is a FBAFileUtil.File


=end text

=back



=head2 FBAObjectSelectionParams

=over 4



=item Description

****** FBA Result Converters ******


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
fba_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
fba_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean


=end text

=back



=head2 FBATsvFiles

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compounds_file has a value which is a FBAFileUtil.File
reactions_file has a value which is a FBAFileUtil.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compounds_file has a value which is a FBAFileUtil.File
reactions_file has a value which is a FBAFileUtil.File


=end text

=back



=head2 MediaCreationParams

=over 4



=item Description

****** Media Converters *********


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media_file has a value which is a FBAFileUtil.File
media_name has a value which is a string
workspace_name has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media_file has a value which is a FBAFileUtil.File
media_name has a value which is a string
workspace_name has a value which is a string


=end text

=back



=head2 MediaObjectSelectionParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
media_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
media_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean


=end text

=back



=head2 PhenotypeSetCreationParams

=over 4



=item Description

****** Phenotype Data Converters *******


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
phenotype_set_file has a value which is a FBAFileUtil.File
phenotype_set_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotype_set_file has a value which is a FBAFileUtil.File
phenotype_set_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string


=end text

=back



=head2 PhenotypeSetObjectSelectionParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_set_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_set_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean


=end text

=back



=head2 PhenotypeSimulationSetObjectSelectionParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_simulation_set_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_simulation_set_name has a value which is a string
save_to_shock has a value which is a FBAFileUtil.boolean


=end text

=back



=cut

package FBAFileUtil::FBAFileUtilClient::RpcClient;
use base 'JSON::RPC::Client';
use POSIX;
use strict;

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $headers, $obj) = @_;
    my $result;


    {
	if ($uri =~ /\?/) {
	    $result = $self->_get($uri);
	}
	else {
	    Carp::croak "not hashref." unless (ref $obj eq 'HASH');
	    $result = $self->_post($uri, $headers, $obj);
	}

    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $headers, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	@$headers,
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
