package WWW::LacunaExpanse::API::Building::SpacePort;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::API::Captcha;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes
has 'index'             => (is => 'rw', default => 0);

my @simple_strings_1    = qw(max_ships docks_available);
my @other_strings_1     = qw(docked_hash);

my @simple_strings_2    = qw(number_of_ships);
my @other_strings_2     = qw(ships);

for my $attr (@simple_strings_1, @other_strings_1) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->get_summary;
            return $self->$attr;
        }
    );
}

for my $attr (@simple_strings_2, @other_strings_2) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->view_all_ships;
            return $self->$attr;
        }
    );
}

# Reset to the first record
#
sub reset_ship {
    my ($self) = @_;

    $self->index(0);
}

# Return the next Ship in the List
#
sub next_ship {
    my ($self) = @_;

    if ($self->index >= $self->count_ships) {
        return;
    }

    my $ship = $self->ships->[$self->index];
    $self->index($self->index + 1);
    return $ship;
}

# Return all ships (or all ships of a particular type)
#
sub all_ships {
    my ($self, $type, $task) = @_;

    my @ships;
    $self->reset_ship;
    while (my $ship = $self->next_ship) {
        if ($type) {
            if ($ship->type eq $type) {
                if ($task) {
                    if ($ship->task eq $task) {
                        push @ships, $ship;
                    }
                }
                else {
                    push @ships, $ship;
                }
            }
        }
        else {
            push @ships, $ship;
        }
    }

    return @ships;
}

# Return all ships by type
#
# e.g. {excavator => \@excavators, fighter => \@fighters}
#
sub all_ships_by_type {
    my ($self) = @_;

    my $type_ref;
    for my $ship ($self->all_ships) {
        my $type = $ship->type;
#        print "Type [$type]\n";
        push @{$type_ref->{$type}}, $ship;
    }
    return $type_ref;
}


# Return the total number of ships
#
sub count_ships {
    my ($self) = @_;

    return scalar @{$self->ships};
}

# Refresh the object from the Server
#
sub view_all_ships {
    my ($self, $filter) = @_;

    my $log = Log::Log4perl->get_logger('SpacePort');
    my $items_per_page  = 500;
    my $page_number     = 1;

    my @ships;

    SHIP:
    while (1) {
        my $result = $self->connection->call($self->url, 'view_all_ships',[
            $self->connection->session_id,
            $self->id,
            {page_number => $page_number, items_per_page => $items_per_page},
            $filter,
        ]);

        $result = $result->{result};

        $self->simple_strings($result, \@simple_strings_2);

        # other strings
        my $ship_found = 0;
        for my $ship_hash (@{$result->{ships}}) {
            $ship_found++;
            my $ship = WWW::LacunaExpanse::API::Ship->new({
                id              => $ship_hash->{id},
                type            => $ship_hash->{type},
                name            => $ship_hash->{name},
                hold_size       => $ship_hash->{hold_size},
                speed           => $ship_hash->{speed},
                stealth         => $ship_hash->{stealth},
                type_human      => $ship_hash->{type_human},
                task            => $ship_hash->{task},
                combat          => $ship_hash->{combat},
                max_occupants   => $ship_hash->{max_occupants},
                date_available  => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_available}),
                date_started    => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_started}),
                date_arrives    => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_arrives}),
                from            => 'TBD',
                to              => 'TBD',
            });

            push @ships, $ship;
        }
        $log->debug("There were $ship_found ships found");
        last SHIP unless $ship_found;
        $page_number++;
    }
    $self->_ships(\@ships);
    return $self->ships;
}


# Refresh the object from the Server
#
sub refresh {
    my ($self) = @_;

    $self->get_summary;
    $self->view_all_ships;
}


sub get_summary {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'view',[
        $self->connection->session_id, $self->id]);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_1);

    # other strings
    # I don't like returning a hash, but it will do for now
    $self->_docked_hash($body->{docked_ships});
}

# Return the number of docked ships
#
sub docked_ships {
    my ($self, $type) = @_;

    if ($type) {
        if ($self->docked_hash()->{$type}) {
            return $self->docked_hash()->{$type};
        }
        return 0;
    }
    my $ships = 0;
    map {$ships += $self->docked_hash()->{$_}} keys %{$self->docked_hash()};
    return $ships;
}

# Get available ships to send to a body
#
sub get_available_ships_for {
    my ($self, $args) = @_;

    my $result = $self->connection->call($self->url, 'get_ships_for',[
        $self->connection->session_id, $self->body_id, $args]);

    my @ships;
    my $body = $result->{result}{available};
    for my $ship_hash (@{$body}) {
        my $ship = WWW::LacunaExpanse::API::Ship->new({
            id                      => $ship_hash->{id},
            type                    => $ship_hash->{type},
            name                    => $ship_hash->{name},
            hold_size               => $ship_hash->{hold_size},
            speed                   => $ship_hash->{speed},
            stealth                 => $ship_hash->{stealth},
            type_human              => $ship_hash->{type_human},
            task                    => $ship_hash->{task},
            date_available          => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_available}),
            date_started            => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_started}),
            estimated_travel_time   => $ship_hash->{estimated_travel_time},
        });
        push @ships, $ship;
    }
    return \@ships;
}


# Send a ship to a target
#
sub send_ship {
    my ($self, $ship_id, $args) = @_;

    
    my $log = Log::Log4perl->get_logger('WWW::LacunaExpanse::API::Connection');

    my $result;
    eval {
        $result = $self->connection->call($self->url, 'send_ship',[
            $self->connection->session_id, $ship_id, $args]);
    };
    if ($@) {
        $log->error("Cannot send ship $@".Dumper($args));
        return;
    }

    # Should return a status block here.
    # For now just return the hash of data received.
    my $body = $result->{result}{ship};
    return $body;
}


# Send a fleet of ships to a target
#
sub send_fleet {
    my ($self, $ships, $target, $speed) = @_;

    my $log = Log::Log4perl->get_logger('WWW::LacunaExpanse::API::Connection');

TRY_AGAIN:
    $speed = $speed || 0;
    my @ship_ids = map {$_->id} @$ships;
    my $result;
    eval {
        $result = $self->connection->call($self->url, 'send_fleet', [
            $self->connection->session_id,
            \@ship_ids,
            $target,
            $speed,
            ]
        );
    };
    if ($@) {
        my ($rpc_error) = $@ =~ /RPC Error \((\d\d\d\d)\)/;
        $log->error("RPC error is $rpc_error");
        if ($rpc_error == 1016) {
            my $captcha = WWW::LacunaExpanse::API::Captcha->new;
            $captcha->fetch;
        }
        goto TRY_AGAIN;
    }

    # Should return a status block here.
    # For now just return the fleet speed.
    my $body = $result->{result}{fleet};
#    $log->error(Dumper($body));
    return $body->[0]{ship}{fleet_speed};
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
