use kb_picaxe::kb_picaxeImpl;

use kb_picaxe::kb_picaxeServer;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = kb_picaxe::kb_picaxeImpl->new;
    push(@dispatch, 'kb_picaxe' => $obj);
}


my $server = kb_picaxe::kb_picaxeServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
