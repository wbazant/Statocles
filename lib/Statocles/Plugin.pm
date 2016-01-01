package Statocles::Plugin;
# ABSTRACT: Base role for Statocles plugins

=head1 SYNOPSIS

    # lib/My/Plugin.pm
    package My::Plugin;
    use Moo; # or Moose
    with 'Statocles::Plugin';

    sub register {
        my ( $self, $site ) = @_;
        # Register things like event handlers and theme helpers
    }

    1;

    # site.yml
    site:
        args:
            plugins:
                name:
                    $class: My::Plugin

=head1 DESCRIPTION

Statocles Plugins are attached to sites and add features such as template helpers
and event handlers.

This is the base role that all plugins should consume.

=cut

use Statocles::Base 'Role';

=method register

    $plugin->register( $site );

Register this plugin with the given L<Statocles::Site
object|Statocles::Site>. This is called automatically when the site is
created.

=cut

requires 'register';

1;
