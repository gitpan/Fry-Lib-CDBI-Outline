use ExtUtils::MakeMaker;
WriteMakefile(NAME=>'Fry::Lib::CDBI::Outline',
	VERSION_FROM=>'lib/Fry/Lib/CDBI/Outline.pm',
	PREREQ_PM=>{Fry::Shell=>'0.08', Class::Data::Global=>'0.01'}
);
