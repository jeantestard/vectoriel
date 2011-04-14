use similarite;
use Data::Dumper;
use PDL;



my $rep="/fouilletextes/corpus2/en/p";
# my $rep="/fouilletextes/corpus2/fr/p";

my @docPaths=<$rep/*>;
my @documents;
foreach $doc (@docPaths){
	open(DOC,$doc);
  	my $g=<DOC>;
	push(@documents,$g);
	close(DOC);
		
}


my $recherche = similarite->new( \@documents, 0.001, 0.1);
$recherche->vectorisationCorpus();

my $motsClefs="parliament council";
#my $query="parlement conseil";

my %resultats = $recherche->requete( $motsClefs );

print"\n Resultats par produit scalaire:\n\n";
print Dumper%resultats;
print join "\n", sort { $resultats{$b} <=> $resultats{$a} } %resultats;

%resultats = $recherche->requeteCosinus( $motsClefs );

print"\n Resultats par mesure Cosinus:\n\n";
print join "\n", sort { $resultats{$b} <=> $resultats{$a} } %resultats;
print"Documents et scores associés:\n";
print Dumper%resultats;
