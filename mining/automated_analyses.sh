#!/bin/bash

# 1. Translate nucleotide to protein sequences
# 2. Run an interpro scan on Protein queries
# 3. Use IPS unfiltered output with this script

#####################################################################################################################
################################################################################################# DECLARING FUNCTIONS
#####################################################################################################################
function quest () {
    local VAR1=$1
    echo -e "\n---------------------------------------------\n"
    echo "a. Number of proteins found in PANTHER"
    echo "b. Species names"
    echo "c. Most abundant proteins"
    echo "d. Output file"
    echo "e. debugging: Extract fasta file"
    echo
    echo "===DANGER==="
    echo "x. Delete the temporary file"
    echo "y. Delete ALL temporary files"
    echo "===EXIT==="
    echo "z. Do nothing and exit"
    echo
    printf "Input only one of the above letters -> "
    read CHOICE
}

function summary () {
    local VAR1=$1
    local VAR2=$2
    local VAR3=$3
    local __out=$VAR3.$VAR1.10-$VAR2.tmp
## create a correct e-value number by repeating zeros
    ZEROS=$(seq -s. "$(echo "${VAR2}+1" | bc)" | tr -d '[:digit:]' | sed 's/./0/g')
    local VARe="0.${ZEROS}1"
## path to panther database
    if [ "$4" == "bridges" ]; then
        VAR4=/pylon2/oc4ifip/bassim/db/panther
    elif [ "$4" == "lired" ]; then
        VAR4=/gpfs/scratch/ballam/db/panther
    else
        VAR4="$4"
    fi
## select panther only proteins by evalue and alignment length
    awk 'NR==FNR {h[$3] = sprintf ("%s\t%s\t%s\t%s\t%s\t",$1,$3,$4,$5,$6); next} {print h[$2],$0}' <(cat $VAR3 | sed 's/ /./g' | cut -f1,4,5,7,8,9 | awk -va="$VAR1" -vp="$VARe" '{n=$4-$5?$5-$4:$4-$5; if(n>=a && $6<=p && $2 == "PANTHER") print $0}' | grep ":" -) <(grep -RFwf <(cat $VAR3 | sed 's/ /./g' | cut -f1,4,5,7,8,9 | awk -va="$VAR1" -vp="$VARe" '{n=$4-$5?$5-$4:$4-$5; if(n>=a && $6<=p && $2 == "PANTHER") print $0}' | grep ":" - | cut -f3) $VAR4) | sed 's/ /./g' | sort -k2 - > $__out
}

function extra () {
    local VAR1=$1
    local VAR2=$2
    if [ "$VAR2" == 1 ]; then
## count number of hits
	cat $VAR1 | wc -l
    elif [ "$VAR2" == 2 ]; then
## select species column
	cat $VAR1 | sort -k2 - | cut -f6 | egrep -o "0_.*:" | sed -e 's/0_//g' -e 's/://g' | sort - | uniq -c | sort -nrk1 > $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt
    elif [ "$VAR2" == 3 ]; then
## select protein function column
	cat $VAR1 | cut -f9 | sort - | uniq -c | sort -nr | sed 's/\./ /g' > $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt
    elif [ "$VAR2" == 4 ]; then
## get all entries
	cp $VAR1 $FILENAME.PANprots.LEN$ALIGNMENT.EVAL$EVAL.txt
	fi
}


function guidelines () {
    tmp=$FILENAME.$ALIGNMENT.10-$EVAL.tmp

    if [ "$CHOICE" == a ]; then
	echo -e "\nHere is the number of hits found in 13GB of a PANTHER database:"
	extra $tmp 1
	echo
    elif [ "$CHOICE" == b ]; then
	      extra $tmp 2
        _LN=$(grep -c "^" $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt)
        _PN=$(head -n 10 $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt | grep -c "^")
	echo -e "\nHere is $_PN of the $_LN most abundant species found by aligning your proteins to 13GB of PANTHER sequences:\nwait ..."
	cat $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt | column -t | less
	head -n 10 $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt
	echo -e "\nI also put the distribution of all other species in:" $FILENAME.PANspecies.LEN$ALIGNMENT.EVAL$EVAL.txt
	echo
    elif [ "$CHOICE" == c ]; then
	      extra $tmp 3
        _LN=$(grep -c "^" $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt)
        _PN=$(head -n 10 $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt | grep -c "^")
	echo -e "\nHere is $_PN of the $_LN most abundant protein functions found among the queried sequences in PANTHER:\nwait ..."
	cat $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt | sed 's/\./ /g' | less
	head -n 10 $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt | sed 's/\./ /g'
	echo -e "\nI also put the full list in:" $FILENAME.PANfunctions.LEN$ALIGNMENT.EVAL$EVAL.txt
	echo
    elif [ "$CHOICE" == d ]; then
	echo -e "\nWriting the protein alignment output from PANTHER to a file. It will contains E-values, protein acc. numbers, contig IDs, and GOs"
	extra $tmp 4
	echo -e "\nI also put the description of all entries found in:" $FILENAME.PANprots.LEN$ALIGNMENT.EVAL$EVAL.txt
	echo -e "\nDone"
	echo
    elif [ "$CHOICE" == e ]; then
	extractFasta

    elif [ "$CHOICE" == x ]; then
	rm $tmp
	echo "$tmp was deleted!"
	exit
    elif [ "$CHOICE" == y ]; then
	find $(dirname $FILENAME) -maxdepth 1 -iname "*tmp" -exec rm {} \;
	echo "All temperory files were deleted!"
	exit
    elif [ "$CHOICE" == z ]; then
	echo -e "Bye!"
	exit
    else
	echo "Stop messing around!"
	echo
    fi
}


function extractFasta () {
##panther output
    if [ -f $FILENAME.PANprots.LEN$ALIGNMENT.EVAL$EVAL.txt ]; then
	printf "String to search for -> "
	read STRING
	egrep -i "$STRING" $FILENAME.PANprots.LEN$ALIGNMENT.EVAL$EVAL.txt >> $FILENAME.PANselected.tsv
	cat $FILENAME.PANselected.tsv | cut -f1 | sed 's/..$//g' | sort - | uniq >> $FILENAME.PANcontigs

	else
	extra $TMP 4
    fi

##all db##
# interpro output
col1="$7-$6"
col2="$8-$7"
for i in $col1 $col2; do
    cat $FILENAME | sed 's/ /./g' | awk '{if($8<=0.0000000001 || $9<=0.0000000001)print $0}' | awk -vc="$i" '{n=c; if(n>=50) print$0}' >> $FILENAME.ALLselected.tsv
done
cat $FILENAME.ALLselected.tsv | cut -f1 | sed 's/..$//g' | sort - | uniq >> $FILENAME.Allcontigs

#cat alp | sort - | uniq | alpp
#rm alp

##compare##
#comm -13 <(cat alpp | sort -| uniq) <(cat pa | sort -| uniq) > pas
#rm pa
#cat pas >> alpp
#rm pas


}

## get the location of tsv files (user defined)
function files () {
    local OUTPUT=$1
    local EXE=$2
    if [ "$EXE" == txt ]; then
        echo
	      find $OUTPUT -maxdepth 2 -iname "*blast*$EXE" | nl | tee blast.tmp
    else
        echo
	      find $OUTPUT -maxdepth 2 -iname "*$EXE" | nl | tee ips.tmp
    fi
    echo
}



#####################################################################################################################
########################################################################## RUN ANALYSES FOR BLAST AND PANTHER OUTPUTS
#####################################################################################################################
echo
echo -e "\n(p) analyses on PANTHER output\n(b) analyses on BLAST output, STRING included\n(s) analyses on Interpro scans"
printf "Choose between a panther, blast or summary analysis (p|b|s) -> "
read ANALYSIS
echo

## user input when executing this script
FILE__PATH=$1

if [ "$ANALYSIS" == s ]; then
#===================== summary analysis, showcase all database entries
#=====================================================================
    while true; do
        files $FILE__PATH tsv
        printf "1. Choose one annotated file from the list above (number) -> "
        read _FN
        FILENAME=$(awk -vf="$_FN" '{if ($1 == f) print $2}' ips.tmp)
        rm ips.tmp
	      printf "2. Choose an E-value for an alignment score [e-0..35] -> "
	      read NUM
	      ZEROS=$(seq -s. "$(echo "$NUM+1" | bc)" | tr -d '[:digit:]' | sed 's/./0/g')
	      EVAL="0.${ZEROS}1"
	      echo "Below is the number of proteins annotated for each database at an E-value of $EVAL"
	      cat $FILENAME | sed 's/ /./g' | cut -f4,9 | awk -ve="$EVAL" '{if($2<=e)print$1}' | sort - | uniq -c | sort -n
        read -n 1 -s
    done

elif [ "$ANALYSIS" == p ]; then
#==================================== analysis on panther output files
#=====================================================================
    files $FILE__PATH tsv
    printf "1. Choose one PANTHER file from the list above (number) -> "
    read _FN
    FILENAME=$(awk -vf="$_FN" '{if ($1 == f) print $2}' ips.tmp)
    rm ips.tmp
    printf "2. Choose an acceptable alignment length [20..1000] -> "
    read ALIGNMENT
    printf "3. Choose an E-value for an alignment score [e-0..35] -> "
    read EVAL
    printf "4. Choose a PANTHER database (bridges|lired|...) -> "
    read DB

    COUNTS=$(grep -c "^" $FILENAME)
    TMP=$FILENAME.$ALIGNMENT.10-$EVAL.tmp

    if [ -f "$TMP" ]; then
	while [ -f "$TMP" ]; do
	    quest $COUNTS
	    guidelines
	    read -n 1 -s
	done
    else
	echo -e "\nSearching in 13GB of PANTHER genomes. I found $COUNTS hits from interpro scans ..."
	summary $ALIGNMENT $EVAL $FILENAME $DB
	while [ -f "$TMP" ]; do
	    quest $COUNTS
	    guidelines
	    read -n 1 -s
	done
    fi

elif [ "$ANALYSIS" == b ]; then
#======================================================== BLAST output
#=====================================================================
    while true; do
    files $FILE__PATH txt
    printf "1. Choose one BLAST file from the list above (number) -> "
    read _FN
    FILENAME=$(awk -vf="$_FN" '{if ($1 == f) print $2}' blast.tmp)
    rm blast.tmp
    printf "2. Choose an E-value for an alignment score [e-0..35] -> "
    read REP_
## create a correct e-value number by repeating zeros
    ZEROS=$(seq -s. "$(echo "${REP_}+1" | bc)" | tr -d '[:digit:]' | sed 's/./0/g')
    EVAL="0.${ZEROS}1"
## get the synthax used to identify each assembled contig


    echo -e "\n--------------------------------------------------------------"
    echo "a. Count sequences based on length, eval, identity, mismatches..."
    echo "b. Extract a fasta file for QUALITY sequences"
    echo "c. Do nothing and exit"
    echo
    printf "Input only one of the above letters -> "
    read CHOICE_BLAST

    if [ "$CHOICE_BLAST" == a ]; then
## Get distribution of number of hits from ANY blast output
	for i in 2 4 10 11 12 14 15; do
## blast categories found in any blast+ output
	    s[2]="1. Query length [max-min] ->"
	    s[4]="2. Target length [max-min] ->"
	    s[10]="3. Bit Score [max-min] ->"
	    s[11]="4. Alignment length [max-min] ->"
	    s[12]="5. Percentage identity [max-min] ->"
	    s[14]="6. Indentical nt [max-min] ->"
	    s[15]="7. Mismatches [max-min] ->"
## show both [max and min] intervals for each blast category
	    egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vg="$i" '{if($9<=e)print$g}' | sort - | uniq -c | sort -k2 -nr | awk -vf="${s[$i]}" 'NR==1{print f,$2"--"}END{print$2}' | sed 'N;s/\n//g'
## get the maximum range of each category
	    _MAX=$(egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vg="$i" '{if($9<=e)print$g}' | sort - | uniq -c | sort -k2 -nr | awk 'NR==1{print$2}')
## show the number of hits for the different categories
## randomly divide the max number of hits
	    h3=$(echo "$_MAX / ($_MAX/50)" | bc)
	    for f in 2 10 20 $h3; do
		_DIV=$(echo "$_MAX / $f" | bc | awk '{printf "%.0f\n",$1}')
		if [ ! "$i" == 15 ]; then
		   egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vg="$i" '{if($9<=e)print$g}' | sort - | uniq -c | sort -k2 -nr | awk -vm="$_DIV" '{if($2>=m) print $1}' | awk -vx="$_DIV" '{sum+=$1;print "Nb of hits >= "x,"is "sum}' | tail -n1
		else
		    egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vg="$i" '{if($9<=e)print$g}' | sort - | uniq -c | sort -k2 -nr | awk -vm="$_DIV" '{if($2<=m) print $1}' | awk -vx="$_DIV" '{sum+=$1;print "Nb of hits <= "x,"is "sum}' | tail -n1
		fi
	    done
	done

	while true; do
## Filter number of hits using the blast categories
	    printf "Select scores from the 7 above blast categories (space separated) -> "
	    IFS=" "
	    read _Q _T _B _A _P _I _M
	    HITS=$(egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vq="$_Q" -vt="$_T" -vb="$_B" -va="$_A" -vp="$_P" -vi="$_I" -vm="$_M" '{if($9<=e && $2>=q && $4>=t && $10>=b && $11>=a && $12>=p && $14>=i && $15<=m) print $1}' | sort - | uniq | wc -l)
	    echo "Number of unique hits found: $HITS"
	done

	elif [ "$CHOICE_BLAST" == b ]; then
## extract fasta based on quality sequences
	find $(dirname $(dirname $FILENAME))  -maxdepth 2 -iname "*trinity*fa*" | nl
	echo
	printf "1. Provide path and filename of transcriptome -> "
	read TRANSCRIPTOME
	echo -e "\nQuery length, target length, bit score, align length, % identity, identical, mismatches"
	printf "2. Input 7 scores for sequence quality filtering (space separated) -> "
	IFS=" "
	read _Q _T _B _A _P _I _M
	echo "Wait ..."
	_FA=$(dirname $TRANSCRIPTOME)/selected.BLAST.q$_Q.t$_T.b$_B.a$_A.p$_P.i$_I.m$_M.EVAL${REP_}.fa
	cat $TRANSCRIPTOME | sed 's/.len.*$//g' | perl -ne 'if(/^>(\S+)/){$c=$i{$1}}$c?print:chomp;$i{$_}=1 if @ARGV' <(egrep "^[^#]" $FILENAME | awk -ve="$EVAL" -vq="$_Q" -vt="$_T" -vb="$_B" -va="$_A" -vp="$_P" -vi="$_I" -vm="$_M" '{if($9<=e && $2>=q && $4>=t && $10>=b && $11>=a && $12>=p && $14>=i && $15<=m) print $1}' | sort - | uniq) - > $_FA
	echo "Extracted $(grep -c "^>" $_FA) fasta sequences based on the options you provided at an E-value of 10-$REP_"
	read -n 1 -s

    else
	exit
    fi
    done
## from blast of STRING
#grep -i "^trinity" selected.ips.allDB.pval.10-10.fa.string.blastx.67494.txt | awk '{if($9<=0.00001 && $10>=50 && $11>=100 && $12>=30 && $14>=50 && $15<=50) print $3}' | sort - | uniq | wc -l

fi



