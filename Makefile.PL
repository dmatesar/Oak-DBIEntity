use ExtUtils::MakeMaker;

my $mm = new MM
 (
  {
   AUTHOR => "Daniel Ruoso <daniel\@ruoso.com>",
   ABSTRACT => "Perl Oak Component Tree",
   NAME => "Oak::DBIEntity",
   VERSION => "1.8",
   PREREQ_PM => 
   {
    'Oak::Persistent'   => '0',
    'Oak::Filer::DBI' => '0',
    'Error' => '0.15',
   }
  }
 );

$mm->flush;
