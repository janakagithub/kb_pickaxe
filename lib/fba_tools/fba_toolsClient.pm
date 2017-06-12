package fba_tools::fba_toolsClient;

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

fba_tools::fba_toolsClient

=head1 DESCRIPTION


A KBase module: fba_tools
This module contains the implementation for the primary methods in KBase for metabolic model reconstruction, gapfilling, and analysis


=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => fba_tools::fba_toolsClient::RpcClient->new,
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
        method => "fba_tools._check_job",
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




=head2 build_metabolic_model

  $return = $obj->build_metabolic_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.BuildMetabolicModelParams
$return is a fba_tools.BuildMetabolicModelResults
BuildMetabolicModelParams is a reference to a hash where the following keys are defined:
	genome_id has a value which is a fba_tools.genome_id
	genome_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	template_id has a value which is a fba_tools.template_id
	template_workspace has a value which is a fba_tools.workspace_name
	coremodel has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
genome_id is a string
workspace_name is a string
media_id is a string
fbamodel_id is a string
template_id is a string
bool is an int
compound_id is a string
expseries_id is a string
BuildMetabolicModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.BuildMetabolicModelParams
$return is a fba_tools.BuildMetabolicModelResults
BuildMetabolicModelParams is a reference to a hash where the following keys are defined:
	genome_id has a value which is a fba_tools.genome_id
	genome_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	template_id has a value which is a fba_tools.template_id
	template_workspace has a value which is a fba_tools.workspace_name
	coremodel has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
genome_id is a string
workspace_name is a string
media_id is a string
fbamodel_id is a string
template_id is a string
bool is an int
compound_id is a string
expseries_id is a string
BuildMetabolicModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string


=end text

=item Description

Build a genome-scale metabolic model based on annotations in an input genome typed object

=back

=cut

sub build_metabolic_model
{
    my($self, @args) = @_;
    my $job_id = $self->_build_metabolic_model_submit(@args);
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

sub _build_metabolic_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _build_metabolic_model_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _build_metabolic_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_build_metabolic_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._build_metabolic_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_build_metabolic_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _build_metabolic_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_build_metabolic_model_submit');
    }
}

 


=head2 build_multiple_metabolic_models

  $return = $obj->build_multiple_metabolic_models($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.BuildMultipleMetabolicModelsParams
$return is a fba_tools.BuildMultipleMetabolicModelsResults
BuildMultipleMetabolicModelsParams is a reference to a hash where the following keys are defined:
	genome_ids has a value which is a reference to a list where each element is a fba_tools.genome_id
	genome_text has a value which is a string
	genome_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	template_id has a value which is a fba_tools.template_id
	template_workspace has a value which is a fba_tools.workspace_name
	coremodel has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
genome_id is a string
workspace_name is a string
media_id is a string
fbamodel_id is a string
template_id is a string
bool is an int
compound_id is a string
expseries_id is a string
BuildMultipleMetabolicModelsResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
ws_fbamodel_id is a string
ws_fba_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.BuildMultipleMetabolicModelsParams
$return is a fba_tools.BuildMultipleMetabolicModelsResults
BuildMultipleMetabolicModelsParams is a reference to a hash where the following keys are defined:
	genome_ids has a value which is a reference to a list where each element is a fba_tools.genome_id
	genome_text has a value which is a string
	genome_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	template_id has a value which is a fba_tools.template_id
	template_workspace has a value which is a fba_tools.workspace_name
	coremodel has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
genome_id is a string
workspace_name is a string
media_id is a string
fbamodel_id is a string
template_id is a string
bool is an int
compound_id is a string
expseries_id is a string
BuildMultipleMetabolicModelsResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
ws_fbamodel_id is a string
ws_fba_id is a string


=end text

=item Description

Build multiple genome-scale metabolic models based on annotations in an input genome typed object

=back

=cut

sub build_multiple_metabolic_models
{
    my($self, @args) = @_;
    my $job_id = $self->_build_multiple_metabolic_models_submit(@args);
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

sub _build_multiple_metabolic_models_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _build_multiple_metabolic_models_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _build_multiple_metabolic_models_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_build_multiple_metabolic_models_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._build_multiple_metabolic_models_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_build_multiple_metabolic_models_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _build_multiple_metabolic_models_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_build_multiple_metabolic_models_submit');
    }
}

 


=head2 gapfill_metabolic_model

  $results = $obj->gapfill_metabolic_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.GapfillMetabolicModelParams
$results is a fba_tools.GapfillMetabolicModelResults
GapfillMetabolicModelParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	target_reaction has a value which is a fba_tools.reaction_id
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	source_fbamodel_id has a value which is a fba_tools.fbamodel_id
	source_fbamodel_workspace has a value which is a fba_tools.workspace_name
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
fbamodel_id is a string
workspace_name is a string
media_id is a string
reaction_id is a string
bool is an int
feature_id is a string
compound_id is a string
expseries_id is a string
GapfillMetabolicModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.GapfillMetabolicModelParams
$results is a fba_tools.GapfillMetabolicModelResults
GapfillMetabolicModelParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	target_reaction has a value which is a fba_tools.reaction_id
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	source_fbamodel_id has a value which is a fba_tools.fbamodel_id
	source_fbamodel_workspace has a value which is a fba_tools.workspace_name
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
fbamodel_id is a string
workspace_name is a string
media_id is a string
reaction_id is a string
bool is an int
feature_id is a string
compound_id is a string
expseries_id is a string
GapfillMetabolicModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string


=end text

=item Description

Gapfills a metabolic model to induce flux in a specified reaction

=back

=cut

sub gapfill_metabolic_model
{
    my($self, @args) = @_;
    my $job_id = $self->_gapfill_metabolic_model_submit(@args);
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

sub _gapfill_metabolic_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _gapfill_metabolic_model_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _gapfill_metabolic_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_gapfill_metabolic_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._gapfill_metabolic_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_gapfill_metabolic_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _gapfill_metabolic_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_gapfill_metabolic_model_submit');
    }
}

 


=head2 run_flux_balance_analysis

  $results = $obj->run_flux_balance_analysis($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.RunFluxBalanceAnalysisParams
$results is a fba_tools.RunFluxBalanceAnalysisResults
RunFluxBalanceAnalysisParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	target_reaction has a value which is a fba_tools.reaction_id
	fba_output_id has a value which is a fba_tools.fba_id
	workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	fva has a value which is a fba_tools.bool
	minimize_flux has a value which is a fba_tools.bool
	simulate_ko has a value which is a fba_tools.bool
	find_min_media has a value which is a fba_tools.bool
	all_reversible has a value which is a fba_tools.bool
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	max_c_uptake has a value which is a float
	max_n_uptake has a value which is a float
	max_p_uptake has a value which is a float
	max_s_uptake has a value which is a float
	max_o_uptake has a value which is a float
	default_max_uptake has a value which is a float
	notes has a value which is a string
	massbalance has a value which is a string
fbamodel_id is a string
workspace_name is a string
media_id is a string
reaction_id is a string
fba_id is a string
bool is an int
feature_id is a string
compound_id is a string
expseries_id is a string
RunFluxBalanceAnalysisResults is a reference to a hash where the following keys are defined:
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	objective has a value which is an int
ws_fba_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.RunFluxBalanceAnalysisParams
$results is a fba_tools.RunFluxBalanceAnalysisResults
RunFluxBalanceAnalysisParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	target_reaction has a value which is a fba_tools.reaction_id
	fba_output_id has a value which is a fba_tools.fba_id
	workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	fva has a value which is a fba_tools.bool
	minimize_flux has a value which is a fba_tools.bool
	simulate_ko has a value which is a fba_tools.bool
	find_min_media has a value which is a fba_tools.bool
	all_reversible has a value which is a fba_tools.bool
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	max_c_uptake has a value which is a float
	max_n_uptake has a value which is a float
	max_p_uptake has a value which is a float
	max_s_uptake has a value which is a float
	max_o_uptake has a value which is a float
	default_max_uptake has a value which is a float
	notes has a value which is a string
	massbalance has a value which is a string
fbamodel_id is a string
workspace_name is a string
media_id is a string
reaction_id is a string
fba_id is a string
bool is an int
feature_id is a string
compound_id is a string
expseries_id is a string
RunFluxBalanceAnalysisResults is a reference to a hash where the following keys are defined:
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	objective has a value which is an int
ws_fba_id is a string


=end text

=item Description

Run flux balance analysis and return ID of FBA object with results

=back

=cut

sub run_flux_balance_analysis
{
    my($self, @args) = @_;
    my $job_id = $self->_run_flux_balance_analysis_submit(@args);
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

sub _run_flux_balance_analysis_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _run_flux_balance_analysis_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _run_flux_balance_analysis_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_run_flux_balance_analysis_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._run_flux_balance_analysis_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_run_flux_balance_analysis_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _run_flux_balance_analysis_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_run_flux_balance_analysis_submit');
    }
}

 


=head2 compare_fba_solutions

  $results = $obj->compare_fba_solutions($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.CompareFBASolutionsParams
$results is a fba_tools.CompareFBASolutionsResults
CompareFBASolutionsParams is a reference to a hash where the following keys are defined:
	fba_id_list has a value which is a reference to a list where each element is a fba_tools.fba_id
	fba_workspace has a value which is a fba_tools.workspace_name
	fbacomparison_output_id has a value which is a fba_tools.fbacomparison_id
	workspace has a value which is a fba_tools.workspace_name
fba_id is a string
workspace_name is a string
fbacomparison_id is a string
CompareFBASolutionsResults is a reference to a hash where the following keys are defined:
	new_fbacomparison_ref has a value which is a fba_tools.ws_fbacomparison_id
ws_fbacomparison_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.CompareFBASolutionsParams
$results is a fba_tools.CompareFBASolutionsResults
CompareFBASolutionsParams is a reference to a hash where the following keys are defined:
	fba_id_list has a value which is a reference to a list where each element is a fba_tools.fba_id
	fba_workspace has a value which is a fba_tools.workspace_name
	fbacomparison_output_id has a value which is a fba_tools.fbacomparison_id
	workspace has a value which is a fba_tools.workspace_name
fba_id is a string
workspace_name is a string
fbacomparison_id is a string
CompareFBASolutionsResults is a reference to a hash where the following keys are defined:
	new_fbacomparison_ref has a value which is a fba_tools.ws_fbacomparison_id
ws_fbacomparison_id is a string


=end text

=item Description

Compares multiple FBA solutions and saves comparison as a new object in the workspace

=back

=cut

sub compare_fba_solutions
{
    my($self, @args) = @_;
    my $job_id = $self->_compare_fba_solutions_submit(@args);
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

sub _compare_fba_solutions_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _compare_fba_solutions_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _compare_fba_solutions_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_compare_fba_solutions_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._compare_fba_solutions_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_compare_fba_solutions_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _compare_fba_solutions_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_compare_fba_solutions_submit');
    }
}

 


=head2 propagate_model_to_new_genome

  $results = $obj->propagate_model_to_new_genome($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.PropagateModelToNewGenomeParams
$results is a fba_tools.PropagateModelToNewGenomeResults
PropagateModelToNewGenomeParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	proteincomparison_id has a value which is a fba_tools.proteincomparison_id
	proteincomparison_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	keep_nogene_rxn has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
fbamodel_id is a string
workspace_name is a string
proteincomparison_id is a string
bool is an int
media_id is a string
compound_id is a string
expseries_id is a string
PropagateModelToNewGenomeResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.PropagateModelToNewGenomeParams
$results is a fba_tools.PropagateModelToNewGenomeResults
PropagateModelToNewGenomeParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	proteincomparison_id has a value which is a fba_tools.proteincomparison_id
	proteincomparison_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	keep_nogene_rxn has a value which is a fba_tools.bool
	gapfill_model has a value which is a fba_tools.bool
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	thermodynamic_constraints has a value which is a fba_tools.bool
	comprehensive_gapfill has a value which is a fba_tools.bool
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	exp_threshold_margin has a value which is a float
	activation_coefficient has a value which is a float
	omega has a value which is a float
	objective_fraction has a value which is a float
	minimum_target_flux has a value which is a float
	number_of_solutions has a value which is an int
fbamodel_id is a string
workspace_name is a string
proteincomparison_id is a string
bool is an int
media_id is a string
compound_id is a string
expseries_id is a string
PropagateModelToNewGenomeResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
	new_fba_ref has a value which is a fba_tools.ws_fba_id
	number_gapfilled_reactions has a value which is an int
	number_removed_biomass_compounds has a value which is an int
ws_fbamodel_id is a string
ws_fba_id is a string


=end text

=item Description

Translate the metabolic model of one organism to another, using a mapping of similar proteins between their genomes

=back

=cut

sub propagate_model_to_new_genome
{
    my($self, @args) = @_;
    my $job_id = $self->_propagate_model_to_new_genome_submit(@args);
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

sub _propagate_model_to_new_genome_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _propagate_model_to_new_genome_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _propagate_model_to_new_genome_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_propagate_model_to_new_genome_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._propagate_model_to_new_genome_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_propagate_model_to_new_genome_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _propagate_model_to_new_genome_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_propagate_model_to_new_genome_submit');
    }
}

 


=head2 simulate_growth_on_phenotype_data

  $results = $obj->simulate_growth_on_phenotype_data($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.SimulateGrowthOnPhenotypeDataParams
$results is a fba_tools.SimulateGrowthOnPhenotypeDataResults
SimulateGrowthOnPhenotypeDataParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	phenotypeset_id has a value which is a fba_tools.phenotypeset_id
	phenotypeset_workspace has a value which is a fba_tools.workspace_name
	phenotypesim_output_id has a value which is a fba_tools.phenotypesim_id
	workspace has a value which is a fba_tools.workspace_name
	all_reversible has a value which is a fba_tools.bool
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
fbamodel_id is a string
workspace_name is a string
phenotypeset_id is a string
phenotypesim_id is a string
bool is an int
feature_id is a string
reaction_id is a string
compound_id is a string
SimulateGrowthOnPhenotypeDataResults is a reference to a hash where the following keys are defined:
	new_phenotypesim_ref has a value which is a fba_tools.ws_phenotypesim_id
ws_phenotypesim_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.SimulateGrowthOnPhenotypeDataParams
$results is a fba_tools.SimulateGrowthOnPhenotypeDataResults
SimulateGrowthOnPhenotypeDataParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	phenotypeset_id has a value which is a fba_tools.phenotypeset_id
	phenotypeset_workspace has a value which is a fba_tools.workspace_name
	phenotypesim_output_id has a value which is a fba_tools.phenotypesim_id
	workspace has a value which is a fba_tools.workspace_name
	all_reversible has a value which is a fba_tools.bool
	feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
	reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
	custom_bound_list has a value which is a reference to a list where each element is a string
	media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
fbamodel_id is a string
workspace_name is a string
phenotypeset_id is a string
phenotypesim_id is a string
bool is an int
feature_id is a string
reaction_id is a string
compound_id is a string
SimulateGrowthOnPhenotypeDataResults is a reference to a hash where the following keys are defined:
	new_phenotypesim_ref has a value which is a fba_tools.ws_phenotypesim_id
ws_phenotypesim_id is a string


=end text

=item Description

Use Flux Balance Analysis (FBA) to simulate multiple growth phenotypes.

=back

=cut

sub simulate_growth_on_phenotype_data
{
    my($self, @args) = @_;
    my $job_id = $self->_simulate_growth_on_phenotype_data_submit(@args);
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

sub _simulate_growth_on_phenotype_data_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _simulate_growth_on_phenotype_data_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _simulate_growth_on_phenotype_data_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_simulate_growth_on_phenotype_data_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._simulate_growth_on_phenotype_data_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_simulate_growth_on_phenotype_data_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _simulate_growth_on_phenotype_data_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_simulate_growth_on_phenotype_data_submit');
    }
}

 


=head2 merge_metabolic_models_into_community_model

  $results = $obj->merge_metabolic_models_into_community_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.MergeMetabolicModelsIntoCommunityModelParams
$results is a fba_tools.MergeMetabolicModelsIntoCommunityModelResults
MergeMetabolicModelsIntoCommunityModelParams is a reference to a hash where the following keys are defined:
	fbamodel_id_list has a value which is a reference to a list where each element is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	mixed_bag_model has a value which is a fba_tools.bool
fbamodel_id is a string
workspace_name is a string
bool is an int
MergeMetabolicModelsIntoCommunityModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
ws_fbamodel_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.MergeMetabolicModelsIntoCommunityModelParams
$results is a fba_tools.MergeMetabolicModelsIntoCommunityModelResults
MergeMetabolicModelsIntoCommunityModelParams is a reference to a hash where the following keys are defined:
	fbamodel_id_list has a value which is a reference to a list where each element is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	fbamodel_output_id has a value which is a fba_tools.fbamodel_id
	workspace has a value which is a fba_tools.workspace_name
	mixed_bag_model has a value which is a fba_tools.bool
fbamodel_id is a string
workspace_name is a string
bool is an int
MergeMetabolicModelsIntoCommunityModelResults is a reference to a hash where the following keys are defined:
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
ws_fbamodel_id is a string


=end text

=item Description

Merge two or more metabolic models into a compartmentalized community model

=back

=cut

sub merge_metabolic_models_into_community_model
{
    my($self, @args) = @_;
    my $job_id = $self->_merge_metabolic_models_into_community_model_submit(@args);
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

sub _merge_metabolic_models_into_community_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _merge_metabolic_models_into_community_model_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _merge_metabolic_models_into_community_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_merge_metabolic_models_into_community_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._merge_metabolic_models_into_community_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_merge_metabolic_models_into_community_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _merge_metabolic_models_into_community_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_merge_metabolic_models_into_community_model_submit');
    }
}

 


=head2 compare_flux_with_expression

  $results = $obj->compare_flux_with_expression($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.CompareFluxWithExpressionParams
$results is a fba_tools.CompareFluxWithExpressionResults
CompareFluxWithExpressionParams is a reference to a hash where the following keys are defined:
	fba_id has a value which is a fba_tools.fba_id
	fba_workspace has a value which is a fba_tools.workspace_name
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	estimate_threshold has a value which is a fba_tools.bool
	maximize_agreement has a value which is a fba_tools.bool
	fbapathwayanalysis_output_id has a value which is a fba_tools.fbapathwayanalysis_id
	workspace has a value which is a fba_tools.workspace_name
fba_id is a string
workspace_name is a string
expseries_id is a string
bool is an int
fbapathwayanalysis_id is a string
CompareFluxWithExpressionResults is a reference to a hash where the following keys are defined:
	new_fbapathwayanalysis_ref has a value which is a fba_tools.ws_fbapathwayanalysis_id
ws_fbapathwayanalysis_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.CompareFluxWithExpressionParams
$results is a fba_tools.CompareFluxWithExpressionResults
CompareFluxWithExpressionParams is a reference to a hash where the following keys are defined:
	fba_id has a value which is a fba_tools.fba_id
	fba_workspace has a value which is a fba_tools.workspace_name
	expseries_id has a value which is a fba_tools.expseries_id
	expseries_workspace has a value which is a fba_tools.workspace_name
	expression_condition has a value which is a string
	exp_threshold_percentile has a value which is a float
	estimate_threshold has a value which is a fba_tools.bool
	maximize_agreement has a value which is a fba_tools.bool
	fbapathwayanalysis_output_id has a value which is a fba_tools.fbapathwayanalysis_id
	workspace has a value which is a fba_tools.workspace_name
fba_id is a string
workspace_name is a string
expseries_id is a string
bool is an int
fbapathwayanalysis_id is a string
CompareFluxWithExpressionResults is a reference to a hash where the following keys are defined:
	new_fbapathwayanalysis_ref has a value which is a fba_tools.ws_fbapathwayanalysis_id
ws_fbapathwayanalysis_id is a string


=end text

=item Description

Merge two or more metabolic models into a compartmentalized community model

=back

=cut

sub compare_flux_with_expression
{
    my($self, @args) = @_;
    my $job_id = $self->_compare_flux_with_expression_submit(@args);
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

sub _compare_flux_with_expression_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _compare_flux_with_expression_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _compare_flux_with_expression_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_compare_flux_with_expression_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._compare_flux_with_expression_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_compare_flux_with_expression_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _compare_flux_with_expression_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_compare_flux_with_expression_submit');
    }
}

 


=head2 check_model_mass_balance

  $results = $obj->check_model_mass_balance($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.CheckModelMassBalanceParams
$results is a fba_tools.CheckModelMassBalanceResults
CheckModelMassBalanceParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	workspace has a value which is a fba_tools.workspace_name
fbamodel_id is a string
workspace_name is a string
CheckModelMassBalanceResults is a reference to a hash where the following keys are defined:
	new_report_ref has a value which is a fba_tools.ws_report_id
ws_report_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.CheckModelMassBalanceParams
$results is a fba_tools.CheckModelMassBalanceResults
CheckModelMassBalanceParams is a reference to a hash where the following keys are defined:
	fbamodel_id has a value which is a fba_tools.fbamodel_id
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	workspace has a value which is a fba_tools.workspace_name
fbamodel_id is a string
workspace_name is a string
CheckModelMassBalanceResults is a reference to a hash where the following keys are defined:
	new_report_ref has a value which is a fba_tools.ws_report_id
ws_report_id is a string


=end text

=item Description

Identifies reactions in the model that are not mass balanced

=back

=cut

sub check_model_mass_balance
{
    my($self, @args) = @_;
    my $job_id = $self->_check_model_mass_balance_submit(@args);
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

sub _check_model_mass_balance_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _check_model_mass_balance_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _check_model_mass_balance_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_check_model_mass_balance_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._check_model_mass_balance_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_check_model_mass_balance_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _check_model_mass_balance_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_check_model_mass_balance_submit');
    }
}

 


=head2 compare_models

  $return = $obj->compare_models($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.ModelComparisonParams
$return is a fba_tools.ModelComparisonResult
ModelComparisonParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	mc_name has a value which is a string
	model_refs has a value which is a reference to a list where each element is a fba_tools.ws_fbamodel_id
	protcomp_ref has a value which is a fba_tools.ws_proteomecomparison_id
	pangenome_ref has a value which is a fba_tools.ws_pangenome_id
workspace_name is a string
ws_fbamodel_id is a string
ws_proteomecomparison_id is a string
ws_pangenome_id is a string
ModelComparisonResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	mc_ref has a value which is a string
ws_report_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.ModelComparisonParams
$return is a fba_tools.ModelComparisonResult
ModelComparisonParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	mc_name has a value which is a string
	model_refs has a value which is a reference to a list where each element is a fba_tools.ws_fbamodel_id
	protcomp_ref has a value which is a fba_tools.ws_proteomecomparison_id
	pangenome_ref has a value which is a fba_tools.ws_pangenome_id
workspace_name is a string
ws_fbamodel_id is a string
ws_proteomecomparison_id is a string
ws_pangenome_id is a string
ModelComparisonResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	mc_ref has a value which is a string
ws_report_id is a string


=end text

=item Description

Compare models

=back

=cut

sub compare_models
{
    my($self, @args) = @_;
    my $job_id = $self->_compare_models_submit(@args);
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

sub _compare_models_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _compare_models_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _compare_models_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_compare_models_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._compare_models_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_compare_models_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _compare_models_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_compare_models_submit');
    }
}

 


=head2 edit_metabolic_model

  $return = $obj->edit_metabolic_model($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.EditMetabolicModelParams
$return is a fba_tools.EditMetabolicModelResult
EditMetabolicModelParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	fbamodel_id has a value which is a fba_tools.ws_fbamodel_id
	fbamodel_output_id has a value which is a fba_tools.ws_fbamodel_id
	data has a value which is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list where each element is a string
workspace_name is a string
ws_fbamodel_id is a string
EditMetabolicModelResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
ws_report_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.EditMetabolicModelParams
$return is a fba_tools.EditMetabolicModelResult
EditMetabolicModelParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	fbamodel_workspace has a value which is a fba_tools.workspace_name
	fbamodel_id has a value which is a fba_tools.ws_fbamodel_id
	fbamodel_output_id has a value which is a fba_tools.ws_fbamodel_id
	data has a value which is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list where each element is a string
workspace_name is a string
ws_fbamodel_id is a string
EditMetabolicModelResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
ws_report_id is a string


=end text

=item Description

Edit models

=back

=cut

sub edit_metabolic_model
{
    my($self, @args) = @_;
    my $job_id = $self->_edit_metabolic_model_submit(@args);
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

sub _edit_metabolic_model_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _edit_metabolic_model_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _edit_metabolic_model_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_edit_metabolic_model_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._edit_metabolic_model_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_edit_metabolic_model_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _edit_metabolic_model_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_edit_metabolic_model_submit');
    }
}

 


=head2 edit_media

  $return = $obj->edit_media($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.EditMediaParams
$return is a fba_tools.EditMediaResult
EditMediaParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	compounds_to_remove has a value which is a reference to a list where each element is a fba_tools.compound_id
	compounds_to_change has a value which is a reference to a list where each element is a reference to a list containing 4 items:
		0: a fba_tools.compound_id
		1: (concentration) a float
		2: (min_flux) a float
		3: (max_flux) a float

	compounds_to_add has a value which is a reference to a list where each element is a reference to a list containing 4 items:
		0: a fba_tools.compound_id
		1: (concentration) a float
		2: (min_flux) a float
		3: (max_flux) a float

	media_output_id has a value which is a fba_tools.media_id
workspace_name is a string
media_id is a string
compound_id is a string
EditMediaResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	new_media_id has a value which is a fba_tools.media_id
ws_report_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.EditMediaParams
$return is a fba_tools.EditMediaResult
EditMediaParams is a reference to a hash where the following keys are defined:
	workspace has a value which is a fba_tools.workspace_name
	media_id has a value which is a fba_tools.media_id
	media_workspace has a value which is a fba_tools.workspace_name
	compounds_to_remove has a value which is a reference to a list where each element is a fba_tools.compound_id
	compounds_to_change has a value which is a reference to a list where each element is a reference to a list containing 4 items:
		0: a fba_tools.compound_id
		1: (concentration) a float
		2: (min_flux) a float
		3: (max_flux) a float

	compounds_to_add has a value which is a reference to a list where each element is a reference to a list containing 4 items:
		0: a fba_tools.compound_id
		1: (concentration) a float
		2: (min_flux) a float
		3: (max_flux) a float

	media_output_id has a value which is a fba_tools.media_id
workspace_name is a string
media_id is a string
compound_id is a string
EditMediaResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	new_media_id has a value which is a fba_tools.media_id
ws_report_id is a string


=end text

=item Description

Edit models

=back

=cut

sub edit_media
{
    my($self, @args) = @_;
    my $job_id = $self->_edit_media_submit(@args);
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

sub _edit_media_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _edit_media_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _edit_media_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_edit_media_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._edit_media_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_edit_media_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _edit_media_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_edit_media_submit');
    }
}

 


=head2 excel_file_to_model

  $return = $obj->excel_file_to_model($p)

=over 4

=item Parameter and return types

=begin html

<pre>
$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
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
        method => "fba_tools._excel_file_to_model_submit",
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
$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
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
        method => "fba_tools._sbml_file_to_model_submit",
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
$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string
WorkspaceRef is a reference to a hash where the following keys are defined:
	ref has a value which is a string

</pre>

=end html

=begin text

$p is a fba_tools.ModelCreationParams
$return is a fba_tools.WorkspaceRef
ModelCreationParams is a reference to a hash where the following keys are defined:
	model_file has a value which is a fba_tools.File
	model_name has a value which is a string
	workspace_name has a value which is a string
	genome has a value which is a string
	biomass has a value which is a reference to a list where each element is a string
	compounds_file has a value which is a fba_tools.File
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
        method => "fba_tools._tsv_file_to_model_submit",
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
$model is a fba_tools.ModelObjectSelectionParams
$f is a fba_tools.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a fba_tools.ModelObjectSelectionParams
$f is a fba_tools.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._model_to_excel_file_submit",
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
$model is a fba_tools.ModelObjectSelectionParams
$f is a fba_tools.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a fba_tools.ModelObjectSelectionParams
$f is a fba_tools.File
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._model_to_sbml_file_submit",
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
$model is a fba_tools.ModelObjectSelectionParams
$files is a fba_tools.ModelTsvFiles
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
ModelTsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a fba_tools.File
	reactions_file has a value which is a fba_tools.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$model is a fba_tools.ModelObjectSelectionParams
$files is a fba_tools.ModelTsvFiles
ModelObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	model_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
ModelTsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a fba_tools.File
	reactions_file has a value which is a fba_tools.File
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
        method => "fba_tools._model_to_tsv_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_model_as_excel_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_model_as_tsv_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_model_as_sbml_file_submit",
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
$fba is a fba_tools.FBAObjectSelectionParams
$f is a fba_tools.File
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$fba is a fba_tools.FBAObjectSelectionParams
$f is a fba_tools.File
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._fba_to_excel_file_submit",
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
$fba is a fba_tools.FBAObjectSelectionParams
$files is a fba_tools.FBATsvFiles
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
FBATsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a fba_tools.File
	reactions_file has a value which is a fba_tools.File
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$fba is a fba_tools.FBAObjectSelectionParams
$files is a fba_tools.FBATsvFiles
FBAObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	fba_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
FBATsvFiles is a reference to a hash where the following keys are defined:
	compounds_file has a value which is a fba_tools.File
	reactions_file has a value which is a fba_tools.File
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
        method => "fba_tools._fba_to_tsv_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_fba_as_excel_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_fba_as_tsv_file_submit",
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
$p is a fba_tools.MediaCreationParams
$return is a fba_tools.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a fba_tools.File
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

$p is a fba_tools.MediaCreationParams
$return is a fba_tools.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a fba_tools.File
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
        method => "fba_tools._tsv_file_to_media_submit",
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
$p is a fba_tools.MediaCreationParams
$return is a fba_tools.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a fba_tools.File
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

$p is a fba_tools.MediaCreationParams
$return is a fba_tools.WorkspaceRef
MediaCreationParams is a reference to a hash where the following keys are defined:
	media_file has a value which is a fba_tools.File
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
        method => "fba_tools._excel_file_to_media_submit",
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
$media is a fba_tools.MediaObjectSelectionParams
$f is a fba_tools.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$media is a fba_tools.MediaObjectSelectionParams
$f is a fba_tools.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._media_to_tsv_file_submit",
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
$media is a fba_tools.MediaObjectSelectionParams
$f is a fba_tools.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$media is a fba_tools.MediaObjectSelectionParams
$f is a fba_tools.File
MediaObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	media_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._media_to_excel_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_media_as_excel_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_media_as_tsv_file_submit",
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
$p is a fba_tools.PhenotypeSetCreationParams
$return is a fba_tools.WorkspaceRef
PhenotypeSetCreationParams is a reference to a hash where the following keys are defined:
	phenotype_set_file has a value which is a fba_tools.File
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

$p is a fba_tools.PhenotypeSetCreationParams
$return is a fba_tools.WorkspaceRef
PhenotypeSetCreationParams is a reference to a hash where the following keys are defined:
	phenotype_set_file has a value which is a fba_tools.File
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
        method => "fba_tools._tsv_file_to_phenotype_set_submit",
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
$phenotype_set is a fba_tools.PhenotypeSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$phenotype_set is a fba_tools.PhenotypeSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._phenotype_set_to_tsv_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_phenotype_set_as_tsv_file_submit",
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
$pss is a fba_tools.PhenotypeSimulationSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$pss is a fba_tools.PhenotypeSimulationSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._phenotype_simulation_set_to_excel_file_submit",
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
$pss is a fba_tools.PhenotypeSimulationSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
boolean is an int
File is a reference to a hash where the following keys are defined:
	path has a value which is a string
	shock_id has a value which is a string

</pre>

=end html

=begin text

$pss is a fba_tools.PhenotypeSimulationSetObjectSelectionParams
$f is a fba_tools.File
PhenotypeSimulationSetObjectSelectionParams is a reference to a hash where the following keys are defined:
	workspace_name has a value which is a string
	phenotype_simulation_set_name has a value which is a string
	save_to_shock has a value which is a fba_tools.boolean
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
        method => "fba_tools._phenotype_simulation_set_to_tsv_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_phenotype_simulation_set_as_excel_file_submit",
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
$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
ExportParams is a reference to a hash where the following keys are defined:
	input_ref has a value which is a string
ExportOutput is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$params is a fba_tools.ExportParams
$output is a fba_tools.ExportOutput
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
        method => "fba_tools._export_phenotype_simulation_set_as_tsv_file_submit",
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

 


=head2 bulk_export_objects

  $output = $obj->bulk_export_objects($params)

=over 4

=item Parameter and return types

=begin html

<pre>
$params is a fba_tools.BulkExportObjectsParams
$output is a fba_tools.BulkExportObjectsResult
BulkExportObjectsParams is a reference to a hash where the following keys are defined:
	refs has a value which is a reference to a list where each element is a string
	all_models has a value which is a fba_tools.bool
	all_fba has a value which is a fba_tools.bool
	all_media has a value which is a fba_tools.bool
	all_phenotypes has a value which is a fba_tools.bool
	all_phenosims has a value which is a fba_tools.bool
	model_format has a value which is a string
	fba_format has a value which is a string
	media_format has a value which is a string
	phenotype_format has a value which is a string
	phenosim_format has a value which is a string
bool is an int
BulkExportObjectsResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	ref has a value which is a string
ws_report_id is a string

</pre>

=end html

=begin text

$params is a fba_tools.BulkExportObjectsParams
$output is a fba_tools.BulkExportObjectsResult
BulkExportObjectsParams is a reference to a hash where the following keys are defined:
	refs has a value which is a reference to a list where each element is a string
	all_models has a value which is a fba_tools.bool
	all_fba has a value which is a fba_tools.bool
	all_media has a value which is a fba_tools.bool
	all_phenotypes has a value which is a fba_tools.bool
	all_phenosims has a value which is a fba_tools.bool
	model_format has a value which is a string
	fba_format has a value which is a string
	media_format has a value which is a string
	phenotype_format has a value which is a string
	phenosim_format has a value which is a string
bool is an int
BulkExportObjectsResult is a reference to a hash where the following keys are defined:
	report_name has a value which is a string
	report_ref has a value which is a fba_tools.ws_report_id
	ref has a value which is a string
ws_report_id is a string


=end text

=item Description



=back

=cut

sub bulk_export_objects
{
    my($self, @args) = @_;
    my $job_id = $self->_bulk_export_objects_submit(@args);
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

sub _bulk_export_objects_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _bulk_export_objects_submit (received $n, expecting 1)");
    }
    {
        my($params) = @args;
        my @_bad_arguments;
        (ref($params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"params\" (value was \"$params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _bulk_export_objects_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_bulk_export_objects_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "fba_tools._bulk_export_objects_submit",
        params => \@args, context => $context});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_bulk_export_objects_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _bulk_export_objects_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_bulk_export_objects_submit');
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
        method => "fba_tools._status_submit",
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
        method => "fba_tools.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'bulk_export_objects',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method bulk_export_objects",
            status_line => $self->{client}->status_line,
            method_name => 'bulk_export_objects',
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
        warn "New client version available for fba_tools::fba_toolsClient\n";
    }
    if ($sMajor == 0) {
        warn "fba_tools::fba_toolsClient version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 bool

=over 4



=item Description

A binary boolean


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



=head2 genome_id

=over 4



=item Description

A string representing a Genome id.


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



=head2 media_id

=over 4



=item Description

A string representing a Media id.


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



=head2 template_id

=over 4



=item Description

A string representing a NewModelTemplate id.


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



=head2 fbamodel_id

=over 4



=item Description

A string representing a FBAModel id.


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



=head2 proteincomparison_id

=over 4



=item Description

A string representing a protein comparison id.


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



=head2 fba_id

=over 4



=item Description

A string representing a FBA id.


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



=head2 fbapathwayanalysis_id

=over 4



=item Description

A string representing a FBAPathwayAnalysis id.


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



=head2 fbacomparison_id

=over 4



=item Description

A string representing a FBA comparison id.


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



=head2 phenotypeset_id

=over 4



=item Description

A string representing a phenotype set id.


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



=head2 phenotypesim_id

=over 4



=item Description

A string representing a phenotype simulation id.


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



=head2 expseries_id

=over 4



=item Description

A string representing an expression matrix id.


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



=head2 reaction_id

=over 4



=item Description

A string representing a reaction id.


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



=head2 feature_id

=over 4



=item Description

A string representing a feature id.


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



=head2 compound_id

=over 4



=item Description

A string representing a compound id.


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



=head2 ws_fbamodel_id

=over 4



=item Description

The workspace ID for a FBAModel data object.
@id ws KBaseFBA.FBAModel


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



=head2 ws_fba_id

=over 4



=item Description

The workspace ID for a FBA data object.
@id ws KBaseFBA.FBA


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



=head2 ws_fbacomparison_id

=over 4



=item Description

The workspace ID for a FBA data object.
@id ws KBaseFBA.FBA


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



=head2 ws_phenotypesim_id

=over 4



=item Description

The workspace ID for a phenotype set simulation object.
@id ws KBasePhenotypes.PhenotypeSimulationSet


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



=head2 ws_fbapathwayanalysis_id

=over 4



=item Description

The workspace ID for a FBA pathway analysis object
@id ws KBaseFBA.FBAPathwayAnalysis


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



=head2 ws_report_id

=over 4



=item Description

The workspace ID for a Report object
@id ws KBaseReport.Report


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



=head2 ws_pangenome_id

=over 4



=item Description

Reference to a Pangenome object in the workspace
@id ws KBaseGenomes.Pangenome


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



=head2 ws_proteomecomparison_id

=over 4



=item Description

Reference to a Proteome Comparison object in the workspace
@id ws GenomeComparison.ProteomeComparison


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



=head2 BuildMetabolicModelParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome_id has a value which is a fba_tools.genome_id
genome_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
template_id has a value which is a fba_tools.template_id
template_workspace has a value which is a fba_tools.workspace_name
coremodel has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome_id has a value which is a fba_tools.genome_id
genome_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
template_id has a value which is a fba_tools.template_id
template_workspace has a value which is a fba_tools.workspace_name
coremodel has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int


=end text

=back



=head2 BuildMetabolicModelResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int


=end text

=back



=head2 BuildMultipleMetabolicModelsParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome_ids has a value which is a reference to a list where each element is a fba_tools.genome_id
genome_text has a value which is a string
genome_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
template_id has a value which is a fba_tools.template_id
template_workspace has a value which is a fba_tools.workspace_name
coremodel has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome_ids has a value which is a reference to a list where each element is a fba_tools.genome_id
genome_text has a value which is a string
genome_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
template_id has a value which is a fba_tools.template_id
template_workspace has a value which is a fba_tools.workspace_name
coremodel has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int


=end text

=back



=head2 BuildMultipleMetabolicModelsResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id


=end text

=back



=head2 GapfillMetabolicModelParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
target_reaction has a value which is a fba_tools.reaction_id
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
source_fbamodel_id has a value which is a fba_tools.fbamodel_id
source_fbamodel_workspace has a value which is a fba_tools.workspace_name
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
target_reaction has a value which is a fba_tools.reaction_id
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
source_fbamodel_id has a value which is a fba_tools.fbamodel_id
source_fbamodel_workspace has a value which is a fba_tools.workspace_name
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int


=end text

=back



=head2 GapfillMetabolicModelResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int


=end text

=back



=head2 RunFluxBalanceAnalysisParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
target_reaction has a value which is a fba_tools.reaction_id
fba_output_id has a value which is a fba_tools.fba_id
workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
fva has a value which is a fba_tools.bool
minimize_flux has a value which is a fba_tools.bool
simulate_ko has a value which is a fba_tools.bool
find_min_media has a value which is a fba_tools.bool
all_reversible has a value which is a fba_tools.bool
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
max_c_uptake has a value which is a float
max_n_uptake has a value which is a float
max_p_uptake has a value which is a float
max_s_uptake has a value which is a float
max_o_uptake has a value which is a float
default_max_uptake has a value which is a float
notes has a value which is a string
massbalance has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
target_reaction has a value which is a fba_tools.reaction_id
fba_output_id has a value which is a fba_tools.fba_id
workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
fva has a value which is a fba_tools.bool
minimize_flux has a value which is a fba_tools.bool
simulate_ko has a value which is a fba_tools.bool
find_min_media has a value which is a fba_tools.bool
all_reversible has a value which is a fba_tools.bool
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
max_c_uptake has a value which is a float
max_n_uptake has a value which is a float
max_p_uptake has a value which is a float
max_s_uptake has a value which is a float
max_o_uptake has a value which is a float
default_max_uptake has a value which is a float
notes has a value which is a string
massbalance has a value which is a string


=end text

=back



=head2 RunFluxBalanceAnalysisResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fba_ref has a value which is a fba_tools.ws_fba_id
objective has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fba_ref has a value which is a fba_tools.ws_fba_id
objective has a value which is an int


=end text

=back



=head2 CompareFBASolutionsParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fba_id_list has a value which is a reference to a list where each element is a fba_tools.fba_id
fba_workspace has a value which is a fba_tools.workspace_name
fbacomparison_output_id has a value which is a fba_tools.fbacomparison_id
workspace has a value which is a fba_tools.workspace_name

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fba_id_list has a value which is a reference to a list where each element is a fba_tools.fba_id
fba_workspace has a value which is a fba_tools.workspace_name
fbacomparison_output_id has a value which is a fba_tools.fbacomparison_id
workspace has a value which is a fba_tools.workspace_name


=end text

=back



=head2 CompareFBASolutionsResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbacomparison_ref has a value which is a fba_tools.ws_fbacomparison_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbacomparison_ref has a value which is a fba_tools.ws_fbacomparison_id


=end text

=back



=head2 PropagateModelToNewGenomeParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
proteincomparison_id has a value which is a fba_tools.proteincomparison_id
proteincomparison_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
keep_nogene_rxn has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
proteincomparison_id has a value which is a fba_tools.proteincomparison_id
proteincomparison_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
keep_nogene_rxn has a value which is a fba_tools.bool
gapfill_model has a value which is a fba_tools.bool
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
thermodynamic_constraints has a value which is a fba_tools.bool
comprehensive_gapfill has a value which is a fba_tools.bool
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
exp_threshold_margin has a value which is a float
activation_coefficient has a value which is a float
omega has a value which is a float
objective_fraction has a value which is a float
minimum_target_flux has a value which is a float
number_of_solutions has a value which is an int


=end text

=back



=head2 PropagateModelToNewGenomeResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id
new_fba_ref has a value which is a fba_tools.ws_fba_id
number_gapfilled_reactions has a value which is an int
number_removed_biomass_compounds has a value which is an int


=end text

=back



=head2 SimulateGrowthOnPhenotypeDataParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
phenotypeset_id has a value which is a fba_tools.phenotypeset_id
phenotypeset_workspace has a value which is a fba_tools.workspace_name
phenotypesim_output_id has a value which is a fba_tools.phenotypesim_id
workspace has a value which is a fba_tools.workspace_name
all_reversible has a value which is a fba_tools.bool
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
phenotypeset_id has a value which is a fba_tools.phenotypeset_id
phenotypeset_workspace has a value which is a fba_tools.workspace_name
phenotypesim_output_id has a value which is a fba_tools.phenotypesim_id
workspace has a value which is a fba_tools.workspace_name
all_reversible has a value which is a fba_tools.bool
feature_ko_list has a value which is a reference to a list where each element is a fba_tools.feature_id
reaction_ko_list has a value which is a reference to a list where each element is a fba_tools.reaction_id
custom_bound_list has a value which is a reference to a list where each element is a string
media_supplement_list has a value which is a reference to a list where each element is a fba_tools.compound_id


=end text

=back



=head2 SimulateGrowthOnPhenotypeDataResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_phenotypesim_ref has a value which is a fba_tools.ws_phenotypesim_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_phenotypesim_ref has a value which is a fba_tools.ws_phenotypesim_id


=end text

=back



=head2 MergeMetabolicModelsIntoCommunityModelParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id_list has a value which is a reference to a list where each element is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
mixed_bag_model has a value which is a fba_tools.bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id_list has a value which is a reference to a list where each element is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
fbamodel_output_id has a value which is a fba_tools.fbamodel_id
workspace has a value which is a fba_tools.workspace_name
mixed_bag_model has a value which is a fba_tools.bool


=end text

=back



=head2 MergeMetabolicModelsIntoCommunityModelResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id


=end text

=back



=head2 CompareFluxWithExpressionParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fba_id has a value which is a fba_tools.fba_id
fba_workspace has a value which is a fba_tools.workspace_name
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
estimate_threshold has a value which is a fba_tools.bool
maximize_agreement has a value which is a fba_tools.bool
fbapathwayanalysis_output_id has a value which is a fba_tools.fbapathwayanalysis_id
workspace has a value which is a fba_tools.workspace_name

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fba_id has a value which is a fba_tools.fba_id
fba_workspace has a value which is a fba_tools.workspace_name
expseries_id has a value which is a fba_tools.expseries_id
expseries_workspace has a value which is a fba_tools.workspace_name
expression_condition has a value which is a string
exp_threshold_percentile has a value which is a float
estimate_threshold has a value which is a fba_tools.bool
maximize_agreement has a value which is a fba_tools.bool
fbapathwayanalysis_output_id has a value which is a fba_tools.fbapathwayanalysis_id
workspace has a value which is a fba_tools.workspace_name


=end text

=back



=head2 CompareFluxWithExpressionResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_fbapathwayanalysis_ref has a value which is a fba_tools.ws_fbapathwayanalysis_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_fbapathwayanalysis_ref has a value which is a fba_tools.ws_fbapathwayanalysis_id


=end text

=back



=head2 CheckModelMassBalanceParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
workspace has a value which is a fba_tools.workspace_name

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
fbamodel_id has a value which is a fba_tools.fbamodel_id
fbamodel_workspace has a value which is a fba_tools.workspace_name
workspace has a value which is a fba_tools.workspace_name


=end text

=back



=head2 CheckModelMassBalanceResults

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
new_report_ref has a value which is a fba_tools.ws_report_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
new_report_ref has a value which is a fba_tools.ws_report_id


=end text

=back



=head2 ModelComparisonParams

=over 4



=item Description

ModelComparisonParams object: a list of models and optional pangenome and protein comparison; mc_name is the name for the new object.

@optional protcomp_ref pangenome_ref


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
mc_name has a value which is a string
model_refs has a value which is a reference to a list where each element is a fba_tools.ws_fbamodel_id
protcomp_ref has a value which is a fba_tools.ws_proteomecomparison_id
pangenome_ref has a value which is a fba_tools.ws_pangenome_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
mc_name has a value which is a string
model_refs has a value which is a reference to a list where each element is a fba_tools.ws_fbamodel_id
protcomp_ref has a value which is a fba_tools.ws_proteomecomparison_id
pangenome_ref has a value which is a fba_tools.ws_pangenome_id


=end text

=back



=head2 ModelComparisonResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
mc_ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
mc_ref has a value which is a string


=end text

=back



=head2 EditMetabolicModelParams

=over 4



=item Description

EditMetabolicModelParams object: arguments for the edit model function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
fbamodel_workspace has a value which is a fba_tools.workspace_name
fbamodel_id has a value which is a fba_tools.ws_fbamodel_id
fbamodel_output_id has a value which is a fba_tools.ws_fbamodel_id
data has a value which is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
fbamodel_workspace has a value which is a fba_tools.workspace_name
fbamodel_id has a value which is a fba_tools.ws_fbamodel_id
fbamodel_output_id has a value which is a fba_tools.ws_fbamodel_id
data has a value which is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list where each element is a string


=end text

=back



=head2 EditMetabolicModelResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
new_fbamodel_ref has a value which is a fba_tools.ws_fbamodel_id


=end text

=back



=head2 EditMediaParams

=over 4



=item Description

EditMediaParams object: arguments for the edit model function


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
compounds_to_remove has a value which is a reference to a list where each element is a fba_tools.compound_id
compounds_to_change has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: a fba_tools.compound_id
	1: (concentration) a float
	2: (min_flux) a float
	3: (max_flux) a float

compounds_to_add has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: a fba_tools.compound_id
	1: (concentration) a float
	2: (min_flux) a float
	3: (max_flux) a float

media_output_id has a value which is a fba_tools.media_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace has a value which is a fba_tools.workspace_name
media_id has a value which is a fba_tools.media_id
media_workspace has a value which is a fba_tools.workspace_name
compounds_to_remove has a value which is a reference to a list where each element is a fba_tools.compound_id
compounds_to_change has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: a fba_tools.compound_id
	1: (concentration) a float
	2: (min_flux) a float
	3: (max_flux) a float

compounds_to_add has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: a fba_tools.compound_id
	1: (concentration) a float
	2: (min_flux) a float
	3: (max_flux) a float

media_output_id has a value which is a fba_tools.media_id


=end text

=back



=head2 EditMediaResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
new_media_id has a value which is a fba_tools.media_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
new_media_id has a value which is a fba_tools.media_id


=end text

=back



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
model_file has a value which is a fba_tools.File
model_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string
biomass has a value which is a reference to a list where each element is a string
compounds_file has a value which is a fba_tools.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model_file has a value which is a fba_tools.File
model_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string
biomass has a value which is a reference to a list where each element is a string
compounds_file has a value which is a fba_tools.File


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
save_to_shock has a value which is a fba_tools.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
model_name has a value which is a string
save_to_shock has a value which is a fba_tools.boolean


=end text

=back



=head2 ModelTsvFiles

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compounds_file has a value which is a fba_tools.File
reactions_file has a value which is a fba_tools.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compounds_file has a value which is a fba_tools.File
reactions_file has a value which is a fba_tools.File


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
save_to_shock has a value which is a fba_tools.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
fba_name has a value which is a string
save_to_shock has a value which is a fba_tools.boolean


=end text

=back



=head2 FBATsvFiles

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
compounds_file has a value which is a fba_tools.File
reactions_file has a value which is a fba_tools.File

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
compounds_file has a value which is a fba_tools.File
reactions_file has a value which is a fba_tools.File


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
media_file has a value which is a fba_tools.File
media_name has a value which is a string
workspace_name has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media_file has a value which is a fba_tools.File
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
save_to_shock has a value which is a fba_tools.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
media_name has a value which is a string
save_to_shock has a value which is a fba_tools.boolean


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
phenotype_set_file has a value which is a fba_tools.File
phenotype_set_name has a value which is a string
workspace_name has a value which is a string
genome has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
phenotype_set_file has a value which is a fba_tools.File
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
save_to_shock has a value which is a fba_tools.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_set_name has a value which is a string
save_to_shock has a value which is a fba_tools.boolean


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
save_to_shock has a value which is a fba_tools.boolean

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
workspace_name has a value which is a string
phenotype_simulation_set_name has a value which is a string
save_to_shock has a value which is a fba_tools.boolean


=end text

=back



=head2 BulkExportObjectsParams

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
refs has a value which is a reference to a list where each element is a string
all_models has a value which is a fba_tools.bool
all_fba has a value which is a fba_tools.bool
all_media has a value which is a fba_tools.bool
all_phenotypes has a value which is a fba_tools.bool
all_phenosims has a value which is a fba_tools.bool
model_format has a value which is a string
fba_format has a value which is a string
media_format has a value which is a string
phenotype_format has a value which is a string
phenosim_format has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
refs has a value which is a reference to a list where each element is a string
all_models has a value which is a fba_tools.bool
all_fba has a value which is a fba_tools.bool
all_media has a value which is a fba_tools.bool
all_phenotypes has a value which is a fba_tools.bool
all_phenosims has a value which is a fba_tools.bool
model_format has a value which is a string
fba_format has a value which is a string
media_format has a value which is a string
phenotype_format has a value which is a string
phenosim_format has a value which is a string


=end text

=back



=head2 BulkExportObjectsResult

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
ref has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
report_name has a value which is a string
report_ref has a value which is a fba_tools.ws_report_id
ref has a value which is a string


=end text

=back



=cut

package fba_tools::fba_toolsClient::RpcClient;
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
