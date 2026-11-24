CREATE OR REPLACE FORCE VIEW IT.SIMGIA_ACTIVO_FIJO AS
SELECT
    b.cod_oficina RBSUC,
    a.cod_tip_articulo RBCTA,
    substr('0'||b.cod_area,-2) RBSEC,
    rownum RBNRO,
    substr('00000'||rownum,-6,2) RBSEQ,
    to_char(b.fec_compra,'YYYYMMDD') RBFCH,
    PAI_INT.FU_SIM_NORM_CADENA(b.descripcion,45) RBDES,
    nvl(b.val_compra,0) RBVALOR,
    nvl(b.dep_acumulada,0) RBDEPAC,
    nvl(decode (a.ano_depreciacion,0,0,round((100/a.ano_depreciacion),2)),0) RBTASAD,
    round(b.dep_mensual_normal,2) RBDEPD,
    nvl(decode ((a.ano_depreciacion - a.ano_dep_acelerado),0,0,round((100/(a.ano_depreciacion - a.ano_dep_acelerado)),2)),0) RBTASAND,
    nvl(b.dep_mensual,0) RBDEPND,
    0 RBESTADO,
    nvl(to_char(b.fec_enajenacion,'YYYYMMDD'),'0') RBFCHEST,
    0 RBFCHIREV,
    decode(b.rev_actual,0,nvl(b.val_compra,0),b.rev_actual) RBREVACVAL,
    nvl(b.rev_depreciacion,0) RBREVACDEP,
    0 RBTASDEPRE,
    0 RBDEPREV,
    0 RBFCHULTRE,--to_char(b.fec_proceso,'YYYYMMDD') RBFCHULTRE,
    round(b.coeficiente,2) RBINDREV,
    0 RBREVVALA,
    0 RBREVDEPA,
    nvl(b.nro_serie,0) RBCODANT,
    b.cod_articulo RBFCHESANT,
    b.cod_bien RBOPRDOR
 from af_articulos a, af_bienes b
   where a.cod_articulo=b.cod_articulo
   and a.ind_act_fijo='S'
   and b.estado<>'B'
;

