
use Test::Lib;
use My::Test;
use Capture::Tiny qw( capture );
use Mojo::IOLoop;
use Test::Mojo;
use Beam::Wire;
use YAML;
use Statocles;
use Statocles::Site;
use TestDeploy;
use TestApp;
use TestStore;
use Statocles::Command::daemon;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

local $ENV{MOJO_LOG_LEVEL} = 'warn';

my $store = TestStore->new(
    path => tempdir,
    objects => [
        Statocles::Document->new(
            path => '/index.html',
            content => 'Index',
        ),
        Statocles::Document->new(
            path => '/foo/index.markdown',
            content => "Foo Index\n\n",
        ),
        Statocles::File->new(
            path => '/image.png',
        ),
    ],
);
$store->path->child( 'image.png' )->touchpath;

# as done by ::Command::daemon, need to ensure is writable because
# distros are read-only and is within that
my $buildpath = $store->path->child( '.statocles', 'build' );
make_writable( $buildpath );

my $site = Statocles::Site->new(
    store => $store,
    apps => {
        base => TestApp->new(
            url_root => '/',
            pages => [ ],
        ),
    },
    deploy => TestDeploy->new,
);

subtest 'root site' => sub {
    my $t = Test::Mojo->new(
        Statocles::Command::daemon::_MOJOAPP->new(
            site => $site,
        ),
    );

    # Check that / gets index.html
    $t->get_ok( "/" )
        ->status_is( 200 )
        ->text_is( p => "Index" )
        ->content_type_is( 'text/html;charset=UTF-8' )
        ;

    # Check that /index.html gets the right content
    $t->get_ok( "/index.html" )
        ->status_is( 200 )
        ->text_is( p => "Index" )
        ->content_type_is( 'text/html;charset=UTF-8' )
        ;

    # Check directory redirect
    $t->get_ok( "/foo" )
        ->status_is( 302 )
        ->header_is( Location => '/foo/' )
        ;
    $t->get_ok( "/foo/" )
        ->status_is( 200 )
        ->content_like( qr{Foo Index} )
        ->or( sub { diag shift->tx->res->body } )
        ->content_type_is( 'text/html;charset=UTF-8' )
        ;

    # Check that malicious URL gets plonked
    $t->get_ok( '/../../../../../etc/passwd' )
        ->status_is( 400 )
        ->or( sub { diag $t->tx->res->body } )
        ;

    # Check that missing URL gets 404'd
    $t->get_ok( "/MISSING_FILE_THAT_SHOULD_ERROR.html" )
        ->status_is( 404 )
        ->or( sub { diag $t->tx->res->body } )
        ;

    $t->get_ok( "/missing" )
        ->status_is( 404 )
        ->or( sub { diag $t->tx->res->body } )
        ;

};

subtest 'nonroot site' => sub {
    my $site = Statocles::Site->new(
        base_url => '/nonroot',
        store => $store,
        deploy => TestDeploy->new,
    );

    my $t = Test::Mojo->new(
        Statocles::Command::daemon::_MOJOAPP->new(
            site => $site,
        ),
    );

    # Check that / redirects
    $t->get_ok( "/" )
        ->status_is( 302 )
        ->header_is( Location => '/nonroot' )
        ->or( sub { diag $t->tx->res->body } )
        ;

    # Check that /nonroot gets index.html
    $t->get_ok( "/nonroot" )
        ->status_is( 200 )
        ->text_is( p => "Index" )
        ->content_type_is( 'text/html;charset=UTF-8' )
        ;

    # Check that /nonroot/index.html gets the right content
    $t->get_ok( "/nonroot/index.html" )
        ->status_is( 200 )
        ->text_is( p => "Index" )
        ->content_type_is( 'text/html;charset=UTF-8' )
        ;
};

subtest '--date option' => sub {
    $site->clear_pages;
    my $t = Test::Mojo->new(
        Statocles::Command::daemon::_MOJOAPP->new(
            site => $site,
            options => {
                date => '9999-12-31',
            },
        ),
    );

    is_deeply { @{ $site->app( 'base' )->last_pages_args } },
        { date => '9999-12-31' },
        'app pages() options are correct';

};

done_testing;
