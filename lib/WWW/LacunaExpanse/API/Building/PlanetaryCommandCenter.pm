package WWW::LacunaExpanse::API::Building::PlanetaryCommandCenter;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::API::Plan;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes
has planet_stats    => (is => 'ro', writer => '_planet_stats', lazy_build => 1);

# Get the planet stats
#
sub _build_planet_stats {
    my ($self) = @_;

    $self->connection->debug(1);
    my $result = $self->connection->call($self->url, 'view',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result}{planet};

    $self->_planet_stats('tbd');
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
