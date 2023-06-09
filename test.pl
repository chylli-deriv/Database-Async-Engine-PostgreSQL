#!/etc/rmg/bin/perl

use 5.026;
use strict;
use warnings;
no indirect qw(fatal);
use utf8;

use Future::AsyncAwait;
use Syntax::Keyword::Try;

use IO::Async::Loop;
use Database::Async;
use Database::Async::Engine::PostgreSQL;

my $loop = IO::Async::Loop->new;

async sub one {
    my $uri=shift;

    $loop->add(my $instance = Database::Async->new(uri => $uri));
    while (1) {
        try {
            await Future->wait_any(
                $loop->timeout_future(after => 0.1),
                $instance->query('SELECT 1')->void,
            );
            await $loop->delay_future(after => 0.1);
        }
        catch {
            say "failed";
            $instance->remove_from_parent;
            #$loop->remove($instance);
            await $loop->delay_future(after => 0.1);
            $loop->add($instance = Database::Async->new(uri => $uri));
        }
    }
}

#one('postgresql://write@%2Fvar%2Frun%2Fpostgresql:5451/chronicle?password=xxxxxxxx')->get
one('postgresql://write@127.0.0.1:5000/fdgbadf?password=fadsg')->get
