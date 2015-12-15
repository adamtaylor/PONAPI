# ABSTRACT: PONAPI - Perl implementation of {JSON:API} (http://jsonapi.org/) v1.0
package PONAPI::DAO::Request::CreateRelationships;

use Moose;

extends 'PONAPI::DAO::Request';

with 'PONAPI::DAO::Request::Role::UpdateLike',
     'PONAPI::DAO::Request::Role::HasDataMethods',
     'PONAPI::DAO::Request::Role::HasID',
     'PONAPI::DAO::Request::Role::HasRelationshipType';

has data => (
    is        => 'ro',
    isa       => 'ArrayRef[HashRef]',
    predicate => 'has_data',
);

sub check_data_type_match { 1 } # to avoid code duplications in HasDataMethods

sub execute {
    my $self = shift;

    if ( $self->is_valid ) {
        local $@;
        eval {
            my @ret = $self->repository->create_relationships( %{ $self } );
            $self->_add_success_meta(@ret)
                if $self->_verify_update_response(@ret);
            1;
        } or do {
            my $e = $@;
            $self->_handle_error($e);
        };
    }

    return $self->response();
}

sub _validate_rel_type {
    my $self     = shift;
    my $type     = $self->type;
    my $rel_type = $self->rel_type;

    super(@_);

    if ( !$self->repository->has_one_to_many_relationship( $type, $rel_type ) ) {
        $self->_bad_request( "Types `$type` and `$rel_type` are one-to-one" );
    }
}


__PACKAGE__->meta->make_immutable;
no Moose; 1;

__END__
