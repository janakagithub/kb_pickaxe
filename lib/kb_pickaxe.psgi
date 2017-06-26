use kb_pickaxe::kb_pickaxeImpl;

use kb_pickaxe::kb_pickaxeServer;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = kb_pickaxe::kb_pickaxeImpl->new;
    push(@dispatch, 'kb_pickaxe' => $obj);
}


my $server = kb_pickaxe::kb_pickaxeServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
