package Padre::Plugin::Dancer::NewApp;

# ABSTRACT: A Dancer New Application

use 5.008;
use strict;
use warnings;
use Cwd               ();
use File::Spec        ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

sub on_newapp {
	my $main = Padre->ide->wx->main;

	my $dialog = dialog($main);
	$dialog->Show(1);
	return;
}

sub get_layout {

	my @layout = (
		[   [ 'Wx::StaticText', undef,        Wx::gettext('Application Name:') ],
			[ 'Wx::TextCtrl',   '_app_name_', '' ],
		],
		[   [ 'Wx::StaticText', undef, Wx::gettext('Parent Directory:') ],
			[ 'Wx::DirPickerCtrl', '_directory_', '', Wx::gettext('Pick parent directory') ],
		],
	);
	push @layout,
		[
		[ 'Wx::Button', '_ok_',     Wx::wxID_OK ],
		[ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ],
		];

	return \@layout;
}

sub dialog {
	my $parent = shift;
	my $config = Padre->ide->config;

	my $layout = get_layout();
	my $dialog = Padre::Wx::Dialog->new(
		parent => $parent,
		title  => Wx::gettext('New Catalyst Application'),
		layout => $layout,
		width  => [ 100, 200 ],
		bottom => 20,
	);

	$dialog->{_widgets_}->{_directory_}->SetPath( $config->module_start_directory );

	$dialog->{_widgets_}->{_ok_}->SetDefault;
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_ok_},     \&ok_clicked );
	Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_cancel_}, \&cancel_clicked );

	$dialog->{_widgets_}->{_app_name_}->SetFocus;

	return $dialog;
}


sub cancel_clicked {
	my ( $dialog, $event ) = @_;

	$dialog->Destroy;

	return;
}

sub ok_clicked {
	my ( $dialog, $event ) = @_;

	my $data = $dialog->get_data;
	$dialog->Destroy;

	my $main = Padre->ide->wx->main;

	# TODO improve input validation !
	if ( $data->{'_app_name_'} =~ m{^\s*$|[^\w\:]}o ) {
		Wx::MessageBox( Wx::gettext('Invalid Application name'), Wx::gettext('missing field'), Wx::wxOK, $main );
		return;
	} elsif ( not $data->{'_directory_'} ) {
		Wx::MessageBox( Wx::gettext('You need to select a base directory'), Wx::gettext('missing field'), Wx::wxOK,
			$main );
		return;
	}

	# We should probably call Catalyst::Helper directly
	# (new() and mk_app()) here, as long as we can redirect
	# print statements to $main->output->AppendText().
	#
	# Perhaps if run_command() were to block before continuing,
	# we could use something like:
	#$main->run_command('catalyst.pl ' . $data->{'_app_name_'});

	# Prepare the output window for the output
	$main->show_output(1);
	$main->output->Remove( 0, $main->output->GetLastPosition );

	my @command = ( 'dancer', '-a', $data->{'_app_name_'}, '-p', $data->{'_directory_'} );

	# go to the selected directory
	#	my $pwd = Cwd::cwd();
	#	chdir $data->{'_directory_'};

	# run command, then immediately restore directory
	my $output_text = qx(@command);

	#	chdir $pwd;

	$main->output->AppendText($output_text);

	my $ret = Wx::MessageBox(
		sprintf( Wx::gettext("%s apparently created. Do you want to open it now?"), $data->{_app_name_} ),
		'Done',
		Wx::wxYES_NO | Wx::wxCENTRE,
		$main,
	);
	if ( $ret == Wx::wxYES ) {
		require Padre::Plugin::Catalyst::Util;
		my $file = Padre::Plugin::Catalyst::Util::find_file_from_output(
			'Root',
			$output_text
		);
		$file = File::Spec->catfile( $data->{'_directory_'}, $file );
		$file = Cwd::realpath($file); # avoid relative paths

		Padre::DB::History->create(
			type => 'files',
			name => $file,
		);
		$main->setup_editor($file);
		$main->refresh;
	}

	return;
}

1;
