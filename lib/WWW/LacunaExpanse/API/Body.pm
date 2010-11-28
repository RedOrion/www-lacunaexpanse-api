package WWW::LacunaExpanse::API::Body;

use Moose;
use Carp;
use Data::Dumper;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'cached'            => (is => 'ro');

my $path = '/body';

my @simple_strings  = qw(image name orbit size type x y);
my @date_strings    = qw();
my @other_strings   = qw(ore star empire water);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update;
            return $self->$attr;
        }
    );
}

# Stringify
use overload '""' => sub {
    my $body = $_[0];

    my $str = "Body\n";
    $str .= "  ID    : ".$body->id."\n";
    $str .= "  Name  : ".$body->name."\n";
    $str .= "  Image : ".$body->image."\n";
    $str .= "  x     : ".$body->x."\n";
    $str .= "  y     : ".$body->y."\n";
    if ($body->can_see) {
        $str .= "  orbit : ".$body->orbit."\n";
        $str .= "  size  : ".$body->size."\n";
        $str .= "  type  : ".$body->type."\n";
        $str .= "  water : ".$body->water."\n";
        $str .= "  star  : ".$body->star->name."\n";
        $str .= $body->ore;
    }
    else {
        $str .= "  No further information\n";
    }

    return $str;
};

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

print "update\n";
    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result}{body};

    $self->simple_strings($body, \@simple_strings);

    $self->date_strings($body, \@date_strings);

    # other strings
print "### water = [".$body->{water}."] ###\n";
    if ($body->{water}) {
        $self->_water($body->{water});
    }
    else {
        $self->_water(0);
    }
    # Ore
    my $ores_hash = $body->{ore};
    my $ores;
    if ($ores_hash) {
        $ores = WWW::LacunaExpanse::API::Ores->new;
        for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite fluorite galena goethite
            gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
            $ores->$ore($ores_hash->{$ore});
        }
    }

    $self->_ore($ores);
    my $star = WWW::LacunaExpanse::API::Star->new({
        id      => $body->{star_id},
        name    => $body->{star_name},
    });
    $self->_star($star);

    $self->_empire('TBD');
}

# See if we can obtain any more information about this body
#
sub can_see {
    my ($self) = @_;

    eval {
        # Force auto-vivification or an error
        my $orbit = $self->orbit;
    };
    if ($@) {
#        print "### ERROR ### [$@]\n";
        return;
    }
    return 1;
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;
