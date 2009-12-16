package Graphs;

use strict;
use warnings;
use Utils;

our $R_CMD = '/software/R-2.9.0/bin/R';

=pod

=head1 METHODS

=head2 plot_stats

        Description: Create graphs for the given data sets.
        Arg [1]    : The statistics collected by e.g. SamTools::collect_detailed_bam_stats. 
                     Multiple graphs can be produced in a single run. The following data 
                     structure is expected:
                            outfile         .. file types supported by R: png, pdf, or jpg
                            title           .. 
                            desc_xvals      .. the x-axis label 
                            desc_yvals      .. the y-axis label
                            barplot         .. 1 for barplot
                            normalize       .. if set, yvals will be scaled so that the max value is 1
                            r_cmd           .. extra R commands to be executed
                            r_plot          .. extra R statements to plot(), such as e.g. "xlim=c(0,10)"
                            data => \[      .. Multiple lines can be plotted in one graph
                                { xvals=>xvals1, yvals=>yvals1, legend=>'desc' },
                                { xvals=>xvals2, yvals=>yvals2 },
                                ...
                            ],
        Returntype : None

=cut

sub plot_stats
{
    my ($stats) = @_;

    if ( !exists($$stats{'data'}) ) { Utils::error("FIXME\n") }
    if ( !exists($$stats{'outfile'}) ) { Utils::error("FIXME\n") }

    if ( !($$stats{'outfile'} =~ /([^.]+)$/ ) ) # Match the suffix
    { 
        Utils::error("Could not determine the filetype of \"$$stats{'outfile'}\".\n") 
    }
    my $file_type = $1;

    my $title   = exists($$stats{'title'}) ? $$stats{'title'} : '';
    my $xlabel  = exists($$stats{'desc_xvals'}) ? $$stats{'desc_xvals'} : '';
    my $ylabel  = exists($$stats{'desc_yvals'}) ? $$stats{'desc_yvals'} : '';
    my $barplot = exists($$stats{'barplot'}) ? 1 : 0;

    if ( $barplot && @{$$stats{'data'}} > 1 ) { Utils::error("TODO: multiple barplots in one graph.\n"); }

    open(my $fh, '>', "$$stats{'outfile'}.R") or Utils::error("$$stats{'outfile'}.R: $!");

    print $fh "par(bg='cornsilk')\n";
    print $fh "$file_type(file='$$stats{'outfile'}')\n";

    my %legend;
    my $set  = 0;
    for my $vals (@{$$stats{'data'}})
    {
        if ( !$vals ) { Utils::error("Given ampty data set for $$stats{'outfile'}\n") }
        if ( !scalar @{$$vals{'xvals'}} ) { Utils::error("The data set is empty for $$stats{'outfile'}\n") }
        if ( exists($$vals{legend}) ) { push @{$legend{label}}, qq["$$vals{legend}"]; }

        my $xrange = "x$set";
        my $yrange = "y$set";
        if ( $set > 0 )
        {
            $xrange = "xrange,x$set";
            $yrange = "yrange,y$set";
        }

        my ($x,$y);
        if ( $barplot )
        {
            $x = "'" . join("','", @{$$vals{'xvals'}}) . "'";
        }
        else
        {
            $x = join(',', @{$$vals{'xvals'}});
        }

        if ( $$stats{normalize} )
        {
            my ($extreme);
            $extreme = $$vals{yvals}->[0];
            for my $y (@{$$vals{'yvals'}})
            {
                if ( abs($y)>$extreme ) { $extreme=abs($y); }
            }

            my @scaled = ();
            for my $y (@{$$vals{'yvals'}})
            {
                push @scaled, 1.0*$y/$extreme;
            }
            $y = join(',', @scaled);
        }
        else { $y = join(',', @{$$vals{'yvals'}}); }

        print $fh qq[
x$set <- c($x)
y$set <- c($y)

xrange <- range($xrange)
yrange <- range($yrange)

];
        $set++;
    }

    print $fh "par(cex=1.25)\n";
    if ( $barplot )
    {
        print $fh "par(las=2)\n";
        print $fh "barplot(y0,,,x0, xlab='$xlabel',ylab='$ylabel')\n";
    }
    else
    {
        my $r_plot = exists($$stats{'r_plot'}) ? ", $$stats{'r_plot'}" : '';
        print $fh "plot(xrange,yrange,type='n', xlab='$xlabel',ylab='$ylabel' $r_plot)\n";
        $set = 0;
        for my $vals (@{$$stats{'data'}})
        {
            my $lines = exists($$vals{lines}) ? $$vals{lines} : '';
            my $type  = exists($$vals{type}) ? "type='$$vals{type}'" : "type='l'";

            if ( exists($$vals{legend}) ) 
            { 
                push @{$legend{col}}, $set+1; 
                push @{$legend{lwd}}, 1; 
            }

            print $fh "lines(x$set,y$set,$type,col=",$set+1,",pch=",$set+1,"$lines)\n";
            $set++;
        }
    }
    print $fh "title(main='$title', font.main=3)\n";
    print $fh $$stats{'r_cmd'} unless !exists($$stats{'r_cmd'});
    if ( exists($legend{label}) )
    {
        my $col   = join(',',@{$legend{col}});
        my $lwd   = join(',',@{$legend{lwd}});
        my $label = join(',',@{$legend{label}});

        print $fh qq[\nlegend("topright",c($label),col=c($col),lwd=c($lwd))\n];
    }

    close $fh;

    Utils::CMD("cat $$stats{'outfile'}.R | $R_CMD --slave --vanilla");
    return;
}


sub create_gc_depth_graph
{
    my ($bindepth_file,$gcdepth_R,$png_file) = @_;

    # Create the R script and run the command.
    open(my $fh, '>', "$png_file.R") or Utils::error("$png_file.R: $!");
    print $fh qq[
source('$gcdepth_R')
depdat = read.depth('$bindepth_file', type='samp2')
gcdepth(depdat, sname = '$png_file', depmax = NULL, hc = TRUE, plotdev=bitmap, nbins = 30, binned = TRUE)
];

    close $fh;
    Utils::CMD("cat $png_file.R | $R_CMD --slave --vanilla");

    return;
}


1;


