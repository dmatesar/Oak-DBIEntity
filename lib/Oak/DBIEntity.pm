package Oak::DBIEntity;

use strict;
use base qw(Oak::Persistent);

=head1 NAME

Oak::DBIEntity - Class for DBI based entity classes

=head1 HIERARCHY

L<Oak::Object|Oak::Object>

L<Oak::Persistent|Oak::Persistent>

L<Oak::DBIEntity|Oak::DBIEntity>

=head1 DESCRIPTION

Base class for DBI based entity classes. This class can be used to
automate the development of business applications, it implements
automatic load and save of data with get and set methods, functions
for listing the objects of a class, functions to handle the
relationships and the constructor with a default interface to create
new objects of a class.

This class is based on methods that will be overriden to specify the
behavior of a class.

P.S.: Methods that are written with UpperCaseLetters are class methods
and methods written with lower_case_letters are object methods.

=head1 ABSTRACT METHODS

=over

=item GetDefaultDBIIo

Returns the Oak::IO::DBI object to be used if there is not a custom object
defined by the SetDBIIo method. Defaults to $::TL::dataModule->dbi. Where
dataModule is a Oak::DataModule and dbi is the name of the Oak::IO::DBI
component. Overrides it if your object is in another place.

=back

=cut

sub GetDefaultDBIIo {
	return $::TL::dataModule->dbi;
}

=over

=item GetFields

Returns a hashref where the key is the name of the table and the value is an
arrayref of arrayrefs describing the table, each row represents a
column. The column representation is another arrayref with two elements.
The first element represents the name of the field and the second represents
the  SQL syntax to describe the field (without the field name).

Ex.:

  {
   User =>
   [
    ["login","VARCHAR(40) NOT NULL DEFAULT ''"],
    ...
   ]
   ...
  }

=back

=cut

sub GetFields {
	return {};
}

=over

=item GetPrimaryKey

Returns an array reference with the fields that are the primary key of
this object.

When implementing table-distributed classes (subclasses), remember that the primary keys
of the tables MUST have the same name and value.

=back

=cut

sub GetPrimaryKey {
	return [];
}

=over

=item GetAutoIncrementFields

Returns a hash reference with the fields that we should auto increment.

The value has no meaning and it is a hash to simplify lookup.

=back

=cut

sub GetAutoIncrementFields {
	return {};
}

=over

=item GetRelationships

Return a hashref describing the relationships of this class. The hash structure follows:

  name_of_the_relationship =>
  {
   type => Relationship type, one of: 1-1, 1-N, N-1, N-N.
   class => The class of the objects at the other side.
   foreign_key => The field that maintain the relationship in this table.
   other_foreign_key => The field that maintain the relationship in the other table
   relation_table => Used in type N-N to specify the relationship table
   on_delete => The name of a method in the current class that will be called
                 when trying to delete this object:
            on_delete_cascade: Delete the objects at the other side (composition)
            on_delete_restrict: Do not delete anything if there are objects at the other side
            on_delete_set_null: Defines the foreign_key with a null value
            default: Delete this entity and do nothing with the other objects
  }

=back

=cut

sub GetRelationships {
	return {};
}

=over

=item GetDefaultValues

Array of hashes with records to be inserted when setting up the entity class.

=back

=cut

sub GetDefaultValues {
	return [];
}

=head1 METHODS

=over

=item GetDBIIo

Returns the Oak::IO::DBI object to be used with this class. Use the
GetDefaultDBIIo or the object defined with the SetDBIIo method.

=back

=cut

sub GetDBIIo {
	my $class = shift;
	$class = ref $class || $class;
	my $obj;
	eval q|$obj = $|.$class.q|::DBIIo_OBJECT|;
	unless ($obj) {
		$obj = $class->GetDefaultDBIIo;
	}
	return $obj;
}



=over

=item SetDBIIo(obj)

Defines which Oak::DBI::IO object to be used in this class from now on.

Remember that a class variable will be set in this module, so, always you
set an obj, remember to set undef after using it, else your dbi object will
never be destroyed.

=back

=cut

sub SetDBIIo {
	my $class = shift;
	$class = ref $class || $class;
	my $obj = shift;
	eval q|$|.$class.q|::DBIIo_OBJECT = $obj|;
}


### INTERNAL ### NO NEED FOR DOCS ###
sub choose_filer {
	my $self = shift;
	my $field = shift;
	my $classfields = $self->GetFields;
	$classfields = {} unless ref $classfields eq "HASH";
	my $found;
	foreach my $table (keys %{$classfields}) {
		my $tablefields = $classfields->{$table};
		$tablefields = [] unless ref $tablefields eq "ARRAY";
		foreach my $tablefield (@{$tablefields}) {
			my $fieldname = $tablefield->[0];
			if ($fieldname eq $field) {
				$found = $table;
				last;
			}
		}
	}
	if ($found) {
		return $found;
	} else {
		throw Oak::Error::ParamsMissing -text => "Unknown Field $field.";
	}
}

### INTERNAL ### NO NEED FOR DOCS ###
sub test_filer {
	my $self = shift;
	my $filer_name = shift;
	require Oak::Filer::DBI;
	my $where;
	foreach my $k (@{$self->GetPrimaryKey}) {
		$where ||= {};
		$where->{$k} = $self->{__properties__}{$k};
	}
	$self->{__filers__}{$filer_name} ||= new Oak::Filer::DBI
	  (
	   io => $self->GetDBIIo,
	   table => $filer_name,
	   where => $where
	  );
}

=over

=item Setup

Creates the table and insert the data specified in the GetDefaultValues method.
XXTODOXX

=back

=cut

sub Setup {
	warn "TODO: Method Setup at Oak::DBIEntity";
}

=over

=item List($query)

List the objects of this class using $query as complement to the SQL.
Returns an array with the objects.

=back

=cut

sub List {
	my $class = shift;
	$class = ref $class || $class;
	my $query = shift || "";
	my $sql = "SELECT * FROM ";
	my $tables = $class->GetFields;
	$tables = {} unless ref $tables eq "HASH";
	$sql .= join(' NATURAL JOIN ',keys %{$tables});
	$sql .= " $query";
	my $sth = $class->GetDBIIo->do_sql($sql);
	my @objects;
	while (my $row = $sth->fetchrow_hashref) {
		my %props;
		foreach my $k (@{$class->GetPrimaryKey}) {
			$props{$k} = $row->{$k};
		}
		my $obj = $class->new(%props);
		$obj->feed(%{$row});
		push @objects, $obj;
	}
	return @objects;
}

=over

=item Count($query)

Count the objects in this class using $query as complement to the SQL.

=back

=cut

sub Count {
	my $class = shift;
	$class = ref $class || $class;
	my $query = shift || "";
	my $sql = "SELECT COUNT(*) FROM ";
	my $tables = $class->GetFields;
	$tables = {} unless ref $tables eq "HASH";
	$sql .= join(' NATURAL JOIN ',keys %{$tables});
	$sql .= " $query";
	my $sth = $class->GetDBIIo->do_sql($sql);
	my ($ret) = $sth->fetchrow_array;
	return $ret;
}

=over

=item constructor(create => {field => value})

Create this object into the system. Insert into the table.

Throws Oak::DBIEntity::Error::InvalidObject if the object already exists.

=item constructor(primary_key => value)

Instanciate the object using the primary key

Throws Oak::DBIEntity::Error::InvalidObject if the object does not exist.

Throws Oak::Error::ParamsMissing if neighter create of primary key passed.

=back

=cut

sub constructor {
	my $self = shift;
	my %params = @_;
	$self->SUPER::constructor(%params);
	my $noPk = scalar(@{$self->GetPrimaryKey});
	foreach my $k (@{$self->GetPrimaryKey}) {
		if ($params{$k}) {
			$noPk--;
		}
	}
	unless ($noPk) {
		my $testPk;
		foreach my $k (@{$self->GetPrimaryKey}) {
			$self->feed($k => $params{$k});
			$testPk = $k;
		}
		my $filer = $self->choose_filer($testPk);
		$self->test_filer($filer);
		my %data = $self->{__filers__}{$filer}->load($testPk);
		unless (exists $data{$testPk}) {
			throw Oak::DBIEntity::Error::InvalidObject -text => $params{$testPk};
		}
	} elsif ($params{create}) {
		my $autoinc=$self->GetAutoIncrementFields();
		my $testPk;
		foreach my $k (@{$self->GetPrimaryKey}) {
			if (exists $params{create}{$k} && defined $params{create}{$k}) {
				$self->feed($k => $params{create}{$k});
			} elsif (exists $autoinc->{$k}) {
 				my $table=$self->choose_filer($k);
				$params{create}{$k}=$self->_get_next_value($table,$k);
				$self->feed($k => $params{create}{$k});
			} else {
			       throw Oak::Error::ParamsMissing -text => "Missing the primary key $k";
			}
			$testPk = $k;
		}
		my $filer = $self->choose_filer($testPk);
		$self->test_filer($filer);
		my %data = $self->{__filers__}{$filer}->load($testPk);
		if (exists $data{$testPk}) {
			throw Oak::DBIEntity::Error::InvalidObject -text => $params{create}{$testPk};
		} else {
			$self->{__filers__}{$filer}->insert(%{$params{create}});
			$self->get(keys %{$params{create}});
		}
	} else {
		throw Oak::Error::ParamsMissing -text => "Missing the primary keys";
	}	
}

sub _get_next_value {
	my $self=shift;
	my $table=shift;
	my $field=shift;
	my $recursion_count=shift || 0;
	my $sth;
	if ($recursion_count>100) {
		throw Oak::DBIEntity::Error::InvalidObject -text => "Could not allocate next value for $table - $field";
	}
	my $sql;
	my $dbi_io = $self->GetDBIIo();
	$table=$dbi_io->quote($table);
	$field=$dbi_io->quote($field);
	$sql="SELECT id FROM __increments__ WHERE tablename=$table AND field=$field";
	$sth = $dbi_io->do_sql($sql);
	my $id=1;
	if (!$sth->rows) {
		$sql="INSERT INTO __increments__ (tablename,field,id) VALUES ($table,$field,$id)";
		$dbi_io->do_sql($sql);
		return 1;
	}
	($id)=$sth->fetchrow_array;
    	$sql="UPDATE __increments__ SET id=id+1 WHERE id=$id AND tablename=$table AND field=$field";
	$sth=$dbi_io->do_sql($sql);
	if ($sth->rows) {
		return ++$id;
	}
	$self->_get_next_value($table,$field,$recursion_count+1);
}

=over

=item list_related($relationshipname,$query)

List the objects in the relationship $relationshipname using $query as a complement to the SQL
Returns an array with the objects.

In this method, the $query must not include the WHERE word.

Throws Oak::DBIEntity::Error::InexistentRelationship if an inexistent relationship is passed.

=back

=cut

sub list_related {
	my $self = shift;
	my $relationshipname = shift;
	my $query = shift || "";
	my $relationships = $self->GetRelationships;
	if (not exists $relationships->{$relationshipname}) {
		throw Oak::DBIEntity::Error::InexistentRelationship -text => $relationshipname;
	}
	my $rel = $relationships->{$relationshipname};
	my $class = $rel->{class};
	eval "require $class";
	my @list;
	for ($rel->{type}) {
		/^(1-1|1-N|N-1)$/ && do { @list = $class->List("WHERE ".$rel->{other_foreign_key}." = ".$self->GetDBIIo->quote($self->get($rel->{foreign_key}))." $query") };
		/^N-N$/ && do { @list = $self->_list_related_n_n($rel,$query) };
	}
	return @list;
}

sub _list_related_n_n {
	my $self = shift;
	my $rel = shift;
	my $query = shift;
	my $class = $rel->{class};
	my $sql = "SELECT * FROM ".$rel->{relation_table}." WHERE ".$rel->{foreign_key}." = ".$self->GetDBIIo->quote($self->get($rel->{foreign_key}))." $query";
	my $sth = $self->GetDBIIo->do_sql($sql);
	my @list;
	while (my $row = $sth->fetchrow_hashref) {
		my $value = $row->{$rel->{other_foreign_key}};
		my $obj = $class->new($rel->{other_foreign_key} => $value);
		push @list, $obj;
	}
	return @list;
}

=over

=item remove_relationship($relationshipname,$object)

Remove the reletionship between $object and this object.

Throws Oak::DBIEntity::Error::InexistentRelationship if an inexistent relationship is passed.

Throws Oak::DBIEntity::Error::InvalidObject if the passed object is not associated with this object

=back

=cut

sub remove_relationship {
	my $self = shift;
	my $relationship = shift;
	my $object = shift;
	my $relationships = $self->GetRelationships;
	if (not exists $relationships->{$relationship}) {
		throw Oak::DBIEntity::Error::InexistentRelationship -text => $relationship;
	}
	my $rel = $relationships->{$relationship};
	for ($rel->{type}) {
		/^1-1$/ && do { $self->_remove_relationship_1_1($rel,$object) };
		/^1-N$/ && do { $self->_remove_relationship_1_N($rel,$object) };
		/^N-1$/ && do { $self->_remove_relationship_N_1($rel,$object) };
		/^N-N$/ && do { $self->_remove_relationship_N_N($rel,$object) };
	}
	return 1;
}

sub _remove_relationship_1_1 {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	if ($object->get($rel->{other_foreign_key}) eq $self->get($rel->{foreign_key})) {
		$object->set($rel->{other_foreign_key} => undef);
		$self->set($rel->{foreign_key} => undef);
	} else {
		throw Oak::DBIEntity::Error::InvalidObject;
	}
}

sub _remove_relationship_1_N {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	if ($object->get($rel->{other_foreign_key}) eq $self->get($rel->{foreign_key})) {
		$object->set($rel->{other_foreign_key} => undef);
	} else {
		throw Oak::DBIEntity::Error::InvalidObject;
	}
}	

sub _remove_relationship_N_1 {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	if ($object->get($rel->{other_foreign_key}) eq $self->get($rel->{foreign_key})) {
		$self->set($rel->{foreign_key} => undef);
	} else {
		throw Oak::DBIEntity::Error::InvalidObject;
	}
}	

sub _remove_relationship_N_N {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	my $sql = "DELETE FROM ".$rel->{relation_table}." WHERE ".$rel->{foreign_key}." = ".$self->GetDBIIo->quote($self->get($rel->{foreign_key}));
	$sql .= " AND ".$rel->{other_foreign_key}." = ".$self->GetDBIIo->quote($object->get($rel->{other_foreign_key}));
	my $sth = $self->GetDBIIo->do_sql($sql);
	if ($sth->rows == 0) {
		throw Oak::DBIEntity::Error::InvalidObject;
	}
}

=over

=item add_relationship($relationshipname,$object)

Add $object to $relationshipname.

Throws Oak::DBIEntity::Error::InexistentRelationship if an inexistent relationship is passed.

=back

=cut

sub add_relationship {
	my $self = shift;
	my $relationship = shift;
	my $object = shift;
	my $relationships = $self->GetRelationships;
	if (not exists $relationships->{$relationship}) {
		throw Oak::DBIEntity::Error::InexistentRelationship -text => $relationship;
	}
	my $rel = $relationships->{$relationship};
	for ($rel->{type}) {
		/^1-1$/ && do { $self->_add_relationship_1_1($rel,$object) };
		/^1-N$/ && do { $self->_add_relationship_1_N($rel,$object) };
		/^N-1$/ && do { $self->_add_relationship_N_1($rel,$object) };
		/^N-N$/ && do { $self->_add_relationship_N_N($rel,$object) };
	}
	return 1;
}

sub _add_relationship_1_1 {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	$object->set($rel->{other_foreign_key} => $self->get($rel->{foreign_key}));
	$self->set($rel->{foreign_key} => $object->get($rel->{other_foreign_key}));
}

sub _add_relationship_1_N {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	$object->set($rel->{other_foreign_key} => $self->get($rel->{foreign_key}));
}	

sub _add_relationship_N_1 {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	$self->set($rel->{foreign_key} => $object->get($rel->{other_foreign_key}));
}	

sub _add_relationship_N_N {
	my $self = shift;
	my $rel = shift;
	my $object = shift;
	my $sql = "INSERT INTO ".$rel->{relation_table}." (".$rel->{foreign_key}.", ".$rel->{other_foreign_key}.") VALUES (".$self->GetDBIIo->quote($self->get($rel->{foreign_key}));
	$sql .= ", ".$self->GetDBIIo->quote($object->get($rel->{other_foreign_key})).")";
	my $sth = $self->GetDBIIo->do_sql($sql);
}

=over

=item purge

Purge this object itself. Suicides...

This method will transverse the relationships, dispatching the on_delete methods. after this, it will delete itself.

=back

=cut

sub purge {
	my $self = shift;
	# Transverse the relationships;
	my $relationships = $self->GetRelationships;
	foreach my $r (keys %{$relationships}) {
		my $on_delete = $relationships->{$r}{on_delete};
		if ($on_delete) {
			eval '$self->'.$on_delete.'($r)';
			if ($@) {
				my $e = Error::prior();
				if ($e) {
					throw $e;
				} else {
					throw Error::Simple -text => $@;
				}
			}
		}
	}
	my $tables = $self->GetFields;
	$tables = {} if ref $tables ne "HASH";
	foreach my $table (keys %{$tables}) {
		$self->test_filer($table);
		$self->{__filers__}{$table}->delete;
	}
}

=head1 ON_DELETE METHODS

The methods in this section can be specified in the on_delete attribute of a relationship.

=over

=item on_delete_cascade($relationshipname)

Delete all the objects in this relationship.

=back

=cut

sub on_delete_cascade {
	my $self = shift;
	my $relationshipname = shift;
	my @list = $self->list_related($relationshipname);
	foreach my $o (@list) {
		$o->purge;
	}
}

=over

=item on_delete_restrict($relationshipname)

Throws Oak::DBIEntity::Error::Restricted if there are objects in this relationship

=back

=cut

sub on_delete_restrict {
	my $self = shift;
	my $relationshipname = shift;
	my @list = $self->list_related($relationshipname);
	if (scalar @list > 0) {
		throw Oak::DBIEntity::Error::Restricted;
	}
}

=over

=item on_delete_set_null($relationshipname)

Defines the foreign_key  of the objects in the relationship as NULL.

=back

=cut

sub on_delete_set_null {
	my $self = shift;
	my $relationshipname = shift;
	my $rels = $self->GetRelationships;
	my $rel = $rels->{relationshipname};
	my @list = $self->list_related($relationshipname);
	foreach my $o (@list) {
		$o->set($rel->{other_foreign_key} => undef);
	}
}

=head1 EXCEPTIONS

=over

=item Oak::DBIEntity::Error::Restricted

Throwed by on_delete_restrict

=back

=cut

package Oak::DBIEntity::Error::Restricted;

use base qw(Error);

sub stringify {
	"There are objects in the relationship. I will not delete this object.";
}

=over

=item Oak::DBIEntity::Error::InexistentRelationship

Throwed by list_related, add_relationship, remove_relationship when the passed relationship
was not declared.

=back

=cut

package Oak::DBIEntity::Error::InexistentRelationship;

use base qw(Error);

sub stringify {
	my $self = shift;
	"The relationship ".$self->{-text}." was not declared.";
}

=over

=item Oak::DBIEntity::Error::InvalidObject

Throwed by remove_relationship when the received object is not associated 
with this object.

=back

=cut

package Oak::DBIEntity::Error::InvalidObject;

use base qw(Error);

sub stringify {
	my $self = shift;
	"The relationship ".$self->{-text}." was not declared.";
}

1;

__END__

=head1 COPYRIGHT

Copyright (c) 2001
Daniel Ruoso <daniel@ruoso.com>
Carlos Eduardo de Andrade Brasileiro <eduardo@oktiva.com.br>
All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
