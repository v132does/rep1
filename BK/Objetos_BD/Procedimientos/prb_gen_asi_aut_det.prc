CREATE OR REPLACE PROCEDURE IT.PRB_GEN_ASI_AUT_DET is
p_fecha date := pag_cal.FU_OBT_FEC_ANTERIOR(1);
p_archivo varchar2(100) := 'ASI_AUTOM_DET_'||TO_CHAR(p_fecha,'YYYYMMDD');
p_corte number := 100000;

v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_CAB varchar2(1000) := '';
V_SQL varchar2(1000) := '';

begin
     --Se limpia la tabla temporal
     execute immediate 'truncate table cb_asi_aut_det_tmp';

     --Se cargan los registros
     insert into cb_asi_aut_det_tmp (
        fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, cod_moneda, desc_rubro,
        mto_mon_rubro, debito, credito, descripcion_asi, referencia, val_cotizacion,
        ref_movimiento, cod_modulo, cod_modalidad, modalidad, cod_ofi_origen, fec_valor, nro_registro)

           select fecha, cod_oficina, nro_asiento, nro_linea, t.cod_rubro, r.cod_moneda, r.descripcion desc_rubro,
             mto_mon_rubro, decode(tip_movimiento, 'D', mto_mon_local, 0) debito,
             decode(tip_movimiento, 'C', mto_mon_local, 0) credito,
             t.descripcion descripcion_asi, referencia, val_cotizacion, ref_movimiento, t.cod_modulo,
             t.cod_modalidad, m.descripcion modalidad, cod_ofi_origen, fec_valor, rownum
        from cb_asi_automaticos_det t, cb_rubros r, ge_modalidades m
       where t.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(6)
         and r.cod_rubro = t.cod_rubro
         and m.cod_modulo = nvl(t.cod_modulo, 2)
         and m.cod_modalidad = nvl(t.cod_modalidad, 21)
       order by nro_asiento, nro_linea;

     -- se consulta cantidad de registros
     select count(*) into v_cant from cb_asi_aut_det_tmp;

     -- redondeo por exceso parcheado
     v_paginas := round(v_cant/p_corte) + 1;

     V_NOM := p_archivo || '.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;

     --se inserta la cabecera
     V_CAB := q'[select 'nro_registro;fecha;cod_oficina;nro_asiento;nro_linea;cod_rubro;cod_moneda;desc_rubro;mto_mon_rubro;debito;credito;descripcion_asi;referencia;val_cotizacion;ref_movimiento;cod_modulo;cod_modalidad;modalidad;cod_ofi_origen;fec_valor;' from dual]';

     prg_gen_archivo_txt(trim(V_NOM),V_CAB,'N',null,'N');

     --se inserta el detalle
     FOR v_cont IN 1 .. v_paginas
     LOOP
       V_SQL := 'select
       nro_registro || CHR(59) ||
       fecha || CHR(59) ||
       cod_oficina || CHR(59) ||
       nro_asiento || CHR(59) ||
       nro_linea || CHR(59) ||
       cod_rubro || CHR(59) ||
       cod_moneda || CHR(59) ||
       desc_rubro || CHR(59) ||
       mto_mon_rubro || CHR(59) ||
       debito || CHR(59) ||
       credito || CHR(59) ||
       descripcion_asi || CHR(59) ||
       referencia || CHR(59) ||
       val_cotizacion || CHR(59) ||
       ref_movimiento || CHR(59) ||
       cod_modulo || CHR(59) ||
       cod_modalidad || CHR(59) ||
       modalidad || CHR(59) ||
       cod_ofi_origen || CHR(59) ||
       fec_valor
       from cb_asi_aut_det_tmp
       where nro_registro between ' || v_ini || ' and ' || v_fin || ' order by nro_registro asc';

       prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');

       v_ini := v_fin + 1;
       v_fin := v_fin + p_corte;
       v_cont2 := v_cont2 + 1;
    END LOOP;

    commit;

    exception
       when others then
          raise_application_error('-20000','Error en PRB_GEN_ASI_AUT_DET'||sqlerrm);

end PRB_GEN_ASI_AUT_DET;
/
