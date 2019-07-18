#!/bin/bash
export PATH=$HOME/.cabal/bin:$PATH
TOPDIR=$(cd $(dirname $(readlink -f $0))/..;pwd)
CSS_TEMPLATE=template.css
FOOTER=${TOPDIR}/internal_doc/footer.html
TODAY=`env LC_TIME=en_US.UTF-8 date +"%Y-%m-%d"`

md2html() {
	cd $1
	local find_extra_args=
	if $2; then
		find ./ -type d -exec mkdir -p ${TOPDIR}/doc/"{}" \;
	else
		find_extra_args="-maxdepth 1"
	fi

	find ./ ${find_extra_args} -iname "*.md" -type f -exec \
    sh -c 'sed "s/@@release_date@@/${1}/g" ${0} > \
    $(dirname ${0})/$(basename ${0%.md}.mdtmp)' \
    "{}" ${TODAY} \;

	find ./ ${find_extra_args} -iname "*.md" -type f -exec \
    sh -c 'pandoc -s --toc \
    -c $(dirname ${0} | sed -e "s/[^\/^.]/./g2" -e "s/[^\/^.]//g")/${2} \
    -A ${3} \
    --highlight-style pygments --filter pandoc-include \
    $(dirname ${0})/$(basename ${0%.md}.mdtmp) \
    -o "${1}/doc/$(dirname ${0})/$(basename ${0%.md}.html)"' "{}" \
    ${TOPDIR} ${CSS_TEMPLATE} ${FOOTER} \;

	find ./ ${find_extra_args} -iname "*.mdtmp" -type f | xargs rm -f
}

md2html ${TOPDIR}/internal_doc false

#md2html ${TOPDIR} false
