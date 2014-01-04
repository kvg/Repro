#!/usr/bin/perl -w

use strict;

use Cwd;
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/lib";

use ParseArgs;
use DM;

my %args = &getCommandArguments(
    'RUN_ID'     => undef,
    'DRY_RUN'    => 1,
    'NUM_JOBS'   => 1,
    'CLUSTER'    => 'localhost',
    'QUEUE'      => 'localhost',
    'KEEP_GOING' => 1
);

my $cwd = getcwd();
my $projectName = basename($cwd);

my $dataDir = "data";
my $listsDir = "lists";
my $resultsDir = "results/$args{'RUN_ID'}";
my $reportsDir = "reports";
my $resourcesDir = "resources";
my $scriptsDir = "scripts";
my $logsDir = "$resultsDir/logs";

my $dm = new DM(
    'dryRun'     => $args{'DRY_RUN'},
    'numJobs'    => $args{'NUM_JOBS'},
    'keepGoing'  => $args{'KEEP_GOING'},
    'cluster'    => $args{'CLUSTER'},
    'queue'      => $args{'QUEUE'},
    'outputFile' => "$resultsDir/dm.log",
);

# ==============
# ANALYSIS RULES
# ==============

#$dm->addRule(target, dependencies, command, 'outputFile' => "$logsDir/target.log");

# ============
# REPORT RULES
# ============

# Prepare report template
my $reportRnwTemplate = "$scriptsDir/report.rnw.template";
my $reportRnw = "$resultsDir/$projectName.$args{'RUN_ID'}.rnw";
my $reportRnwCmd = "sed 's|<DATA_DIR>|$dataDir|g' $reportRnwTemplate | sed 's|<LISTS_DIR>|$listsDir|g' | sed 's|<RESULTS_DIR>|$resultsDir|g' | sed 's|<RESOURCES_DIR>|$resourcesDir|g' | sed 's|<SCRIPTS_DIR>|$scriptsDir|g' > $reportRnw";
$dm->addRule($reportRnw, [$reportRnwTemplate], $reportRnwCmd, 'cluster' => 'localhost');

# Copy our tufte-report class to the right place
my $tufteClassTemplate = "$resourcesDir/tufte-report.cls";
my $tufteClass = "$resultsDir/tufte-report.cls";
my $tufteClassCmd = "cp $tufteClassTemplate $tufteClass";
$dm->addRule($tufteClass, $tufteClassTemplate, $tufteClassCmd, 'cluster' => 'localhost');

# Evaluate the R code within the report and generate a .tex file
my $reportTex = "$resultsDir/$projectName.$args{'RUN_ID'}.tex";
my $reportTexCmd = "Rscript -e \"library(knitr); knit('$reportRnw', output='$reportTex')\"";
$dm->addRule($reportTex, $reportRnw, $reportTexCmd, 'cluster' => 'localhost');

# Compile the .tex file into a .pdf file
my $reportPdf = "$resultsDir/$projectName.$args{'RUN_ID'}.pdf";
my $reportPdfCmd = "latexmk -gg -nobibtex -pdf -pdflatex='pdflatex -interaction nonstopmode' -bm $projectName -outdir=$resultsDir -use-make $reportTex";
$dm->addRule($reportPdf, [$reportTex, $tufteClass], $reportPdfCmd, 'cluster' => 'localhost');

# Copy the .pdf file to the reports directory
my $reportPdfCopy = "$reportsDir/$projectName.$args{'RUN_ID'}.pdf";
my $reportPdfCopyCmd = "cp $reportPdf $reportPdfCopy";
$dm->addRule($reportPdfCopy, $reportPdf, $reportPdfCopyCmd, 'cluster' => 'localhost');

$dm->execute();
