package GitInsight::Obj;

 use strict;
 use warnings;
 use utf8;

 #use feature ();

 our $feature = eval {
     require feature;
     feature->import();
     1;
 };


 # Only Perl 5.14+ requires it on demand
 use IO::Handle ();

 # Protect subclasses using AUTOLOAD
 sub DESTROY { }

 sub import {
     my $class = shift;
     return unless my $flag = shift;

     # Base
     if ( $flag eq '-base' ) { $flag = $class }

     # Strict
     elsif ( $flag eq '-strict' ) { $flag = undef }

     # Module
     elsif ( ( my $file = $flag ) && !$flag->can('new') ) {
         $file =~ s!::|'!/!g;
         require "$file.pm";
     }

     # ISA
     if ($flag) {
         my $caller = caller;
         no strict 'refs';
         push @{"${caller}::ISA"}, $flag;
         *{"${caller}::has"} = sub { attr( $caller, @_ ) };
     }

     # Mojo modules are strict!
     $_->import for qw(strict warnings utf8);
     if ($feature) {
         feature->import(':5.10');
     }
 }

 sub attr {
     my ( $self, $attrs, $default ) = @_;
     return unless ( my $class = ref $self || $self ) && $attrs;

     die 'Default has to be a code reference or constant value'
         if ref $default && ref $default ne 'CODE';

     for my $attr ( @{ ref $attrs eq 'ARRAY' ? $attrs : [$attrs] } ) {
         die qq{Attribute "$attr" invalid}
             unless $attr =~ /^[a-zA-Z_]\w*$/;

         # Header (check arguments)
         my $code = "package $class;\nsub $attr {\n  if (\@_ == 1) {\n";

         # No default value (return value)
         unless ( defined $default ) { $code .= "    return \$_[0]{'$attr'};" }

         # Default value
         else {

             # Return value
             $code
                 .= "    return \$_[0]{'$attr'} if exists \$_[0]{'$attr'};\n";

             # Return default value
             $code .= "    return \$_[0]{'$attr'} = ";
             $code .=
                 ref $default eq 'CODE'
                 ? '$default->($_[0]);'
                 : '$default;';
         }

         # Store value
         $code .= "\n  }\n  \$_[0]{'$attr'} = \$_[1];\n";

         # Footer (return invocant)
         $code .= "  \$_[0];\n}";

         warn "-- Attribute $attr in $class\n$code\n\n"
             if $ENV{GitInsight_OBJ_DEBUG};
         die "GitInsight::Obj error: $@" unless eval "$code;1";
     }
 }

 sub new {
     my $class = shift;
     bless @_ ? @_ > 1 ? {@_} : { %{ $_[0] } } : {}, ref $class || $class;
 }

 sub tap {
     my ( $self, $cb ) = @_;
     $_->$cb for $self;
     return $self;
 }

 1;
 __END__

 =encoding utf8

 =head1 NAME

 GitInsight::Obj - Minimal base class for GitInsight

 =head1 SYNOPSIS

   package Cat;
   use GitInsight::Obj -base;

   has name => 'Nyan';
   has [qw(birds mice)] => 2;

   package Tiger;
   use GitInsight::Obj 'Cat';

   has friend  => sub { Cat->new };
   has stripes => 42;

   package main;
   use GitInsight::Obj -strict;

   my $mew = Cat->new(name => 'Longcat');
   say $mew->mice;
   say $mew->mice(3)->birds(4)->mice;

   my $rawr = Tiger->new(stripes => 23, mice => 0);
   say $rawr->tap(sub { $_->friend->name('Tacgnol') })->mice;

 =head1 DESCRIPTION

 L<GitInsight::Obj> is a simple base class for L<GitInsight>, a fork of  L<Mojo::Base>.

   # Automatically enables "strict", "warnings", "utf8" and Perl 5.10 features
   use GitInsight::Obj -strict;
   use GitInsight::Obj -base;
   use GitInsight::Obj 'SomeBaseClass';

 All three forms save a lot of typing.

   # use GitInsight::Obj -strict;
   use strict;
   use warnings;
   use utf8;
   use feature ':5.10';
   use IO::Handle ();

   # use GitInsight::Obj -base;
   use strict;
   use warnings;
   use utf8;
   use feature ':5.10';
   use IO::Handle ();
   use GitInsight::Obj;
   push @ISA, 'GitInsight::Obj';
   sub has { GitInsight::Obj::attr(__PACKAGE__, @_) }

   # use GitInsight::Obj 'SomeBaseClass';
   use strict;
   use warnings;
   use utf8;
   use feature ':5.10';
   use IO::Handle ();
   require SomeBaseClass;
   push @ISA, 'SomeBaseClass';
   use GitInsight::Obj;
   sub has { GitInsight::Obj::attr(__PACKAGE__, @_) }

 =head1 FUNCTIONS

 L<GitInsight::Obj> implements the following functions like L<Mojo::Base>, which can be imported with
 the C<-base> flag or by setting a base class.

 =head2 has

   has 'name';
   has [qw(name1 name2 name3)];
   has name => 'foo';
   has name => sub {...};
   has [qw(name1 name2 name3)] => 'foo';
   has [qw(name1 name2 name3)] => sub {...};

 Create attributes for hash-based objects, just like the L</"attr"> method.

 =head1 METHODS

 L<GitInsight::Obj> implements the following methods.

 =head2 attr

   $object->attr('name');
   BaseSubClass->attr('name');
   BaseSubClass->attr([qw(name1 name2 name3)]);
   BaseSubClass->attr(name => 'foo');
   BaseSubClass->attr(name => sub {...});
   BaseSubClass->attr([qw(name1 name2 name3)] => 'foo');
   BaseSubClass->attr([qw(name1 name2 name3)] => sub {...});

 Create attribute accessor for hash-based objects, an array reference can be
 used to create more than one at a time. Pass an optional second argument to
 set a default value, it should be a constant or a callback. The callback will
 be executed at accessor read time if there's no set value. Accessors can be
 chained, that means they return their invocant when they are called with an
 argument.

 =head2 new

   my $object = BaseSubClass->new;
   my $object = BaseSubClass->new(name => 'value');
   my $object = BaseSubClass->new({name => 'value'});

 This base class provides a basic constructor for hash-based objects. You can
 pass it either a hash or a hash reference with attribute values.

 =head2 tap

   $object = $object->tap(sub {...});

 K combinator, tap into a method chain to perform operations on an object
 within the chain. The object will be the first argument passed to the callback
 and is also available as C<$_>.

 =head1 DEBUGGING

 You can set the C<GitInsight_OBJ_DEBUG> environment variable to get some advanced
 diagnostics information printed to C<STDERR>.

   GitInsight_OBJ_DEBUG=1

 =head1 SEE ALSO

 L<GitInsight>, L<Mojo::Base>.

 =cut
