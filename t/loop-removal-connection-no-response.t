#!/usr/bin/env perl
use strict;
use warnings;

no indirect qw(fatal);
use utf8;

use Test::More;
use Test::NoLeaks;
use Future::AsyncAwait;
use Syntax::Keyword::Try;

use IO::Async::Loop;
use Database::Async;
use Database::Async::Engine::PostgreSQL;

my $loop = IO::Async::Loop->new;

my $uri = URI->new('postgresql://example@127.0.0.1:5000/empty?password=example-password');

# Attempt to connect and remove from the event loop a few times in succession.
# This would also need to confirm no FDs or other leftovers.
async sub cleanup_ok {
    test_noleaks(
        code => sub {
            note "print something";
            (async sub {
                $loop->add(
                    my $instance = Database::Async->new(
                        uri => $uri,
                        engine => {connection_timeout => 0.1}
                    )
                );

                try {
                    await Future->wait_any(
                        $loop->timeout_future(after => 0.5),
                        $instance->query('select 1')->void,
                    );
                    await $loop->delay_future(after => 0.05);
                } catch ($e) {
                    note "failed - $e";
                    $instance->remove_from_parent;
                }
            })->()->get;
        },
        track_memory => 1,
        track_fds => 1,
        passes => 10,
        warmup_passes => 0,
        tolerate_hits => 1,
    );
}

subtest 'connection accepted but no response' => sub {
    my $listener = $loop->listen(
        service => 0,
        socktype => 'stream',
        on_stream => sub {
            my ($stream) = @_;
            # We don't want to read, and we don't want to write - just sit
            # there passively after accepting the connection
            $stream->configure(on_read => sub { 0 });
            $loop->add($stream)
        }
    )->get;
    my $port = $listener->read_handle->sockport;
    note "Listening on port ", $port;
    $uri->port($port);
    cleanup_ok()->get;
    done_testing;
};

done_testing;
