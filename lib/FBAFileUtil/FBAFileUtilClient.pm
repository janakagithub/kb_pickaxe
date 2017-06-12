package FBAFileUtil::FBAFileUtilClient;

use JSON::RPC::Client;
use POSIX;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
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
	my %arg_hash2 = @args;
	if (exists $arg_hash2{"token"}) {
	    $self->{token} = $arg_hash2{"token"};
	} elsif (exists $arg_hash2{"user_id"}) {
	    my $token = Bio::KBase::AuthToken->new(@args);
	    if (!$token->error_message) {
	        $self->{token} = $token->token;
	    }
	}
	
	if (exists $self->{token})
	{
	    $self->{client}->{token} = $self->{token};
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function excel_file_to_model (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to excel_file_to_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'excel_file_to_model');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.excel_file_to_model",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'excel_file_to_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method excel_file_to_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'excel_file_to_model',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function sbml_file_to_model (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to sbml_file_to_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'sbml_file_to_model');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.sbml_file_to_model",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'sbml_file_to_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method sbml_file_to_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'sbml_file_to_model',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function tsv_file_to_model (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to tsv_file_to_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'tsv_file_to_model');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.tsv_file_to_model",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'tsv_file_to_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method tsv_file_to_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'tsv_file_to_model',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function model_to_excel_file (received $n, expecting 1)");
    }
    {
	my($model) = @args;

	my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to model_to_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'model_to_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.model_to_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'model_to_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method model_to_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'model_to_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function model_to_sbml_file (received $n, expecting 1)");
    }
    {
	my($model) = @args;

	my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to model_to_sbml_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'model_to_sbml_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.model_to_sbml_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'model_to_sbml_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method model_to_sbml_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'model_to_sbml_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function model_to_tsv_file (received $n, expecting 1)");
    }
    {
	my($model) = @args;

	my @_bad_arguments;
        (ref($model) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"model\" (value was \"$model\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to model_to_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'model_to_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.model_to_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'model_to_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method model_to_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'model_to_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_model_as_excel_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_model_as_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_model_as_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_model_as_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_model_as_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_model_as_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_model_as_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_model_as_tsv_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_model_as_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_model_as_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_model_as_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_model_as_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_model_as_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_model_as_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_model_as_sbml_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_model_as_sbml_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_model_as_sbml_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_model_as_sbml_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_model_as_sbml_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_model_as_sbml_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_model_as_sbml_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fba_to_excel_file (received $n, expecting 1)");
    }
    {
	my($fba) = @args;

	my @_bad_arguments;
        (ref($fba) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"fba\" (value was \"$fba\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fba_to_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fba_to_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.fba_to_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'fba_to_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fba_to_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'fba_to_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function fba_to_tsv_file (received $n, expecting 1)");
    }
    {
	my($fba) = @args;

	my @_bad_arguments;
        (ref($fba) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"fba\" (value was \"$fba\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to fba_to_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'fba_to_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.fba_to_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'fba_to_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method fba_to_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'fba_to_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_fba_as_excel_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_fba_as_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_fba_as_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_fba_as_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_fba_as_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_fba_as_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_fba_as_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_fba_as_tsv_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_fba_as_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_fba_as_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_fba_as_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_fba_as_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_fba_as_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_fba_as_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function tsv_file_to_media (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to tsv_file_to_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'tsv_file_to_media');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.tsv_file_to_media",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'tsv_file_to_media',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method tsv_file_to_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'tsv_file_to_media',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function excel_file_to_media (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to excel_file_to_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'excel_file_to_media');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.excel_file_to_media",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'excel_file_to_media',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method excel_file_to_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'excel_file_to_media',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function media_to_tsv_file (received $n, expecting 1)");
    }
    {
	my($media) = @args;

	my @_bad_arguments;
        (ref($media) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"media\" (value was \"$media\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to media_to_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'media_to_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.media_to_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'media_to_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method media_to_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'media_to_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function media_to_excel_file (received $n, expecting 1)");
    }
    {
	my($media) = @args;

	my @_bad_arguments;
        (ref($media) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"media\" (value was \"$media\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to media_to_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'media_to_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.media_to_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'media_to_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method media_to_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'media_to_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_media_as_excel_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_media_as_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_media_as_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_media_as_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_media_as_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_media_as_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_media_as_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_media_as_tsv_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_media_as_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_media_as_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_media_as_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_media_as_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_media_as_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_media_as_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function tsv_file_to_phenotype_set (received $n, expecting 1)");
    }
    {
	my($p) = @args;

	my @_bad_arguments;
        (ref($p) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"p\" (value was \"$p\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to tsv_file_to_phenotype_set:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'tsv_file_to_phenotype_set');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.tsv_file_to_phenotype_set",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'tsv_file_to_phenotype_set',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method tsv_file_to_phenotype_set",
					    status_line => $self->{client}->status_line,
					    method_name => 'tsv_file_to_phenotype_set',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function phenotype_set_to_tsv_file (received $n, expecting 1)");
    }
    {
	my($phenotype_set) = @args;

	my @_bad_arguments;
        (ref($phenotype_set) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"phenotype_set\" (value was \"$phenotype_set\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to phenotype_set_to_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'phenotype_set_to_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.phenotype_set_to_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'phenotype_set_to_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method phenotype_set_to_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'phenotype_set_to_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_phenotype_set_as_tsv_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_phenotype_set_as_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_phenotype_set_as_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_phenotype_set_as_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_phenotype_set_as_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_phenotype_set_as_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_phenotype_set_as_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function phenotype_simulation_set_to_excel_file (received $n, expecting 1)");
    }
    {
	my($pss) = @args;

	my @_bad_arguments;
        (ref($pss) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"pss\" (value was \"$pss\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to phenotype_simulation_set_to_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'phenotype_simulation_set_to_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.phenotype_simulation_set_to_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'phenotype_simulation_set_to_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method phenotype_simulation_set_to_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'phenotype_simulation_set_to_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function phenotype_simulation_set_to_tsv_file (received $n, expecting 1)");
    }
    {
	my($pss) = @args;

	my @_bad_arguments;
        (ref($pss) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"pss\" (value was \"$pss\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to phenotype_simulation_set_to_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'phenotype_simulation_set_to_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.phenotype_simulation_set_to_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'phenotype_simulation_set_to_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method phenotype_simulation_set_to_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'phenotype_simulation_set_to_tsv_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_phenotype_simulation_set_as_excel_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_phenotype_simulation_set_as_excel_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_phenotype_simulation_set_as_excel_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_phenotype_simulation_set_as_excel_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_phenotype_simulation_set_as_excel_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_phenotype_simulation_set_as_excel_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_phenotype_simulation_set_as_excel_file',
				       );
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

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function export_phenotype_simulation_set_as_tsv_file (received $n, expecting 1)");
    }
    {
	my($params) = @args;

	my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_phenotype_simulation_set_as_tsv_file:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'export_phenotype_simulation_set_as_tsv_file');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "FBAFileUtil.export_phenotype_simulation_set_as_tsv_file",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'export_phenotype_simulation_set_as_tsv_file',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method export_phenotype_simulation_set_as_tsv_file",
					    status_line => $self->{client}->status_line,
					    method_name => 'export_phenotype_simulation_set_as_tsv_file',
				       );
    }
}
 
  
sub status
{
    my($self, @args) = @_;
    if ((my $n = @args) != 0) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function status (received $n, expecting 0)");
    }
    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
        method => "FBAFileUtil.status",
        params => \@args,
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => 'status',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
                          );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method status",
                        status_line => $self->{client}->status_line,
                        method_name => 'status',
                       );
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
