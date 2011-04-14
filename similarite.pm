package similarite;

use warnings;
use strict;
use Lingua::Stem;
use Lingua::Stem::Fr;
use Data::Dumper;
use PDL;
use POSIX qw(log10);


our $VERSION = '0.01';

=head1 SIMILARITE

Paquet utilisant la mesure cosinus ou le produit scalaire pour déterminier la similarité de documents à une requête

=head1 SYNOPSIS

	use similarite;
	
	my $recherche = similarite->new( documents => \@documents, seuilSimilarite => 0.001);
	$recherche->vectorisationCorpus();
	my %resultats = $recherche->requete( $motsClefs );

=head1 DESCRIPTION

	On pass en argument un répertoire contenant une liste de fichiers (documents)
qui sont chargés en mémoire.
Les documents sont stockés dans des objets PDL pour plus d'efficacité. 
L'indexation comprends plusieurs traitements:

-segmentation
-lemmatisation
-élimination des mots vides (liste noire)

	La similarité des documents une fois traitée peut être calculée soit par la mesure cosinus soit par le produit scalaire.
On peut déterminer un seul de similarité minimale ( par défaut 0.001).


=head1 FONCTIONS

=over 	

=item new documents => référence sur un tableau

	Constructeur. 
	Les arguments doivent contenire une référence sur un tableau de documents.
Argument optionnel:
le seuil de similarité etre 0 et 1( défaut à 0.001) qui permet de définir la pertinence minimale des documents à sélectionner.

=cut

sub new {
	
	my $class=shift;
	my $self={};
	$self->{'documents'} = shift;
	$self->{'seuilSimilariteCosinus'} = shift;
	$self->{'seuilSimilariteScalaire'} = shift;
	$self->{'motsVides'} = motsVides("blacklist.txt");

	return bless $self, $class;
}

=item vectorisationCorpus


L'index crée la liste des mots du corpus et leurs fréquences,
et les vecteur de documents en pondérant ou non par TF*IDF
Les vecteurs sont référencés par un tableau et leur normes dans un autre.


=cut

sub vectorisationCorpus() {
	my ( $self ) = @_;
	$self->indexation();
	my @vecs;
	my @vecs2;

	foreach my $doc ( @{ $self->{'documents'} }) {
		my $vec = $self->tfIdf( $doc );
		push @vecs, norm $vec;
		push @vecs2, $vec;
		
	}
	$self->{'vecteursDoc'} = \@vecs2; # les vecteurs pour le produit scalaire
	$self->{'vecteursNormes'} = \@vecs; #les normes des vecteurs pour la mesure cosinus

}

=item requete 

Retourne les documents correspondants aux mots clés de la requête.
La requête est vectorisée comme les documents.
On définit un filtre : le niveau minimal de similarité des documents que l'on souhaite obtenir.

Renvoie un tableau document => score de simlarité, 
où scoreSimilarite est obtenu par produit scalaire. 

=cut

sub requete {
	my ( $self, $requete ) = @_;
	my $vecteurRequete = $self->tfIdf( $requete );	

	 my %tableauResultat = $self->scalaire( $vecteurRequete );
	
	
	my %documents;
	foreach my $indice ( keys %tableauResultat ) {
		my $doc = $self->{'documents'}->[$indice];
		my $scoreSimilarite = $tableauResultat{$indice};
		$documents{$doc} = $scoreSimilarite;
	}

	return %documents;
}


=item requeteCosinus

Retourne les documents correspondants aux mots clés de la requête.
La requête est vectorisée comme les documents.
On définit un filtre : le niveau minimal de similarité des documents que l'on souhaite obtenir.

Renvoie un tableau document => score de simlarité, où scoreSimilarite
est la mesure Cosinus, entre 0 et 1.


=cut

sub requeteCosinus {
	my ( $self, $requete ) = @_;
	# my $vecteurRequete = $self->vectorisationSimple( $query );
	my $vecteurRequete = $self->tfIdf( $requete  );	
 my %tableauResultat = $self->mesureCosinus( norm $vecteurRequete );
	
	
	my %documents;
	foreach my $indice ( keys %tableauResultat ) {
		my $doc = $self->{'documents'}->[$indice];
		my $scoreSimilarite = $tableauResultat{$indice};
		$documents{$doc} = $scoreSimilarite;
	}

	return %documents;
}

=item vocabulaire

Segmentation et lexemisation
La fonction renvoie un tableau associatif mot=>frequence


=cut

sub vocabulaire {	
	
	# Segmentation sur les espaces et la ponctuation	
	my ( $self, $document ) = @_;
	my %vocDocument;  
	my @mots = map { lexemisation($_) }
				 grep { !( exists $self->{'motsVides'}->{$_} ) }
				map { lc($_) } 
				 map {  $_ =~/([a-z\-']+)/i} 
				split /\s+/, $document;
	#incrementation des frequences du corpus			
	do { $_++ } for @vocDocument{@mots};
	return %vocDocument;
}	

=item lexemisation

lexemisation utilisant Lingua::Stem::stem pour l'anglais 
et Lingua::Stem::Fr::stem_word pour le français.

=cut

sub lexemisation {
		my ( $mot) = @_;
		my $lexeme = Lingua::Stem::stem( $mot );
		# my $lexeme = Lingua::Stem::Fr::stem_word( $mot );
		return $lexeme->[0];
}

=item indexation

Indexation des Mots du corpus et leurs fréquences

=cut

sub indexation {
	my ( $self ) = @_;
	my %dictionnaireGlobal;

	
	foreach my $doc ( @{ $self->{documents} } ) {
		
	
		my %mots = $self->vocabulaire( $doc );
		foreach my $mot ( keys %mots ) {	
			$dictionnaireGlobal{$mot} += $mots{$mot};
			
			
		}
	}
	print Dumper%dictionnaireGlobal;
	
	my %index; # hashage mot => position 
	my @tableauMotsClasses = sort keys %dictionnaireGlobal;
	@index{@tableauMotsClasses} = (1..$#tableauMotsClasses );
	
	my %vocDoc; #nombre de documents par mots. 
	foreach my $word (@tableauMotsClasses){
		my $nbdoc=0;
		foreach my $doc ( @{ $self->{documents} } ) {
			my %words = $self->vocabulaire( $doc );
			if (exists $words{$word}){
				$nbdoc++;
			}
		}
		$vocDoc{$word} = $nbdoc;
	}


	$self->{'frequencesMots'} = \%vocDoc;
	$self->{'word_freq'} = \%dictionnaireGlobal;
	$self->{'indexationMots'} = \%index;
	# $self->{'listeMots'} = \@stableauMotsClasses;
	$self->{'nombreMots'} = scalar @tableauMotsClasses;
}

=item vectorisationSimple

Vectorisation sans tf*idf

=cut

sub vectorisationSimple {
	my ( $self, $doc ) = @_;
	my %words = $self->vocabulaire( $doc );	
	my $vector = zeroes $self->{'nombreMots'};
	foreach my $w ( keys %words ) {
		my $value = $words{$w};
		my $offset = $self->{'indexationMots'}->{$w};
		index( $vector, $offset ) .= $value; # mettre la valeur à l'indice "offset" du vecteur
	}
	
	return $vector;
}


=item tfIdf

Vectorisation avec pondération par tf*idf

=cut

sub tfIdf {
	my ( $self, $doc ) = @_;
	my %words = $self->vocabulaire( $doc );	
	my $vector = zeroes $self->{'nombreMots'};
	
	print"$doc\n";
	foreach my $w ( keys %words ) {
		my $nbMotsDoc=scalar (keys %words);
		my $frequenceMot=$words{$w};
		
		 	my $nbDocuments= scalar @{ $self->{'documents'}}; # nombre de documents	
		 	my $freqmot=$self->{'word_freq'}->{$w};	
			my $tfidf=$words{$w}*log10($nbDocuments / $self->{'frequencesMots'}->{$w});							   #
			print"$tfidf $w \n";	
			
	
		my $value = $tfidf;
		my $offset = $self->{'indexationMots'}->{$w};
		index( $vector, $offset ) .= $value;
	}
	return $vector;
	
}


=item scalaire

Calcul de similarité par produit scalaire

=cut

sub scalaire {
	my ( $self, $query_vec ) = @_;
	my %scalaires;
	my $indice = 0;
	foreach my $vec ( @{ $self->{'vecteursDoc'}  }) {

		my $scalaire;

		for (my $i=0; $i <= $self->{'nombreMots'}-1; ++$i) {
			$scalaire += index($vec,$i)*index($query_vec,$i) ;
		}

		$scalaire =$scalaire->sclr(); 
		$scalaires{$indice} = $scalaire if $scalaire > $self->{'seuilSimilariteScalaire'};
		$indice++;
	}
	return %scalaires;
}

=item mesureCosinus

Calcul de similarité par mesure cosinus

=cut

sub mesureCosinus {
	my ( $self, $vecteurRequete ) = @_;
	my %mesuresCosinus;
	my $indice = 0;
	foreach my $vecteur ( @{ $self->{'vecteursNormes'}  }) {
		my $mesureCosinus = cosinus( $vecteur, $vecteurRequete );
		$mesuresCosinus{$indice} = $mesureCosinus if $mesureCosinus > $self->{'seuilSimilariteCosinus'};
		$indice++;
	}
	return %mesuresCosinus;
}


=item cosinus

Calcul la mesure cosinus de deux vecteurs

=cut

# Prends en argument les normes de deux vecteurs.
sub cosinus {
	my ( $vec1, $vec2 ) = @_;
	my $mesureCosinus = inner( $vec1, $vec2 );
			  # fonction PDL, ici $cos  = ( $vec1 * $vec2 ) / ||$vec1|| x ||$vec2||
		
		return $mesureCosinus->sclr();  # coercion de l'objet PDL vers une variable Perl

	
}

=item motsVides

Charge la liste des mots vides

=cut

sub motsVides {
	my $fichier=shift;
	my %motsVides;

	open(MOTS,$fichier);
	while (<MOTS>) {
		chomp;
		$motsVides{$_}++;
	}
	close(MOTS);

	return \%motsVides;
}



1;
