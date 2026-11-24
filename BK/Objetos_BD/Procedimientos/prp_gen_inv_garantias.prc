CREATE OR REPLACE PROCEDURE IT.PRP_GEN_INV_GARANTIAS is

p_archivo varchar2(100) := 'INV_GAR_'||TO_CHAR(PAG_CAL.FU_OBT_FEC_ANTERIOR(6),'YYYYMMDD');
p_corte number := 10000;

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
      execute immediate 'truncate table inv_gar_tmp';

     --Se cargan los registros
     insert into inv_gar_tmp (
        referencia,
        rubro,
        des_asiento,
        oficina,
        sec_contable,
        res,
        cod_persona,
        cod_garantia,
        des_garantia,
        nro_garantia,
        estado_garantia,
        fec_inicio,
        fec_vencimiento,
        moneda,
        valor,
        val_tasacion,
        fec_ult_tasacion,
        nro_escritura,
        des_escribano,
        situacion,
        situacion_garantia)

       select rownum,
         ta.cod_rubro rubro,
         ta.descripcion des_asiento,
         g.cod_oficina oficina,
         sc.descripcion sec_contable,
         ta.ind_residente res,
         g.cod_persona cod_persona,
         g.cod_garantia cod_garantia,
         tg.descripcion des_garantia,
         g.nro_garantia nro_garantia,
         fue_obt_des_refcodes('EST_GARANTIA',g.estado) Estado_Garantia,
         g.fec_inicio fec_inicio,
         g.fec_vencimiento fec_vencimiento,
         g.cod_moneda moneda,
         g.valor valor,
         g.val_tasacion val_tasacion,
         g.fec_ult_tasacion fec_ult_tasacion,
         g.nro_escritura nro_escritura,
         e.descripcion des_escribano,
         g.situacion,
         decode(g.situacion, null, null, fue_obt_des_refcodes('SIT_GARANTIA', g.situacion)) Situacion_Garantia
    from ge_entes e,
         pr_gar_tipos tg,
         ge_clientes c,
         pr_garantias g,
         ge_transacciones t,
         ge_tip_asientos ta,
         ge_sec_contables sc
  where g.cod_persona = c.cod_persona
     and g.cod_garantia = tg.cod_garantia
     and g.cod_ent_escribania = e.cod_ente(+)
     and ta.cod_sec_contable = sc.cod_sec_contable(+)
     and t.cod_transaccion = tg.cod_transaccion1
     and t.cod_modalidad = 61
     and t.cod_tip_asiento = ta.cod_tip_asiento
     and ta.cod_moneda = g.cod_moneda
     and ta.tip_movimiento = 'D'
     and g.estado <> 'N'
 UNION
      select rownum,
         ta.cod_rubro rubro,
         ta.descripcion des_asiento,
         g.cod_oficina oficina,
         sc.descripcion sec_contable,
         ta.ind_residente res,
         g.cod_persona cod_persona,
         g.cod_garantia cod_garantia,
         tg.descripcion des_garantia,
         g.nro_garantia nro_garantia,
         fue_obt_des_refcodes('EST_GARANTIA',g.estado) Estado_Garantia,
         g.fec_inicio fec_inicio,
         g.fec_vencimiento fec_vencimiento,
         g.cod_moneda moneda,
         g.valor valor,
         g.val_tasacion val_tasacion,
         g.fec_ult_tasacion fec_ult_tasacion,
         g.nro_escritura nro_escritura,
         e.descripcion des_escribano,
         g.situacion,
         decode(g.situacion, null, null, fue_obt_des_refcodes('SIT_GARANTIA', g.situacion)) Situacion_Garantia
    from ge_entes e,
         pr_gar_tipos tg,
         ge_clientes c,
         pr_garantias g,
         ge_transacciones t,
         ge_tip_asientos ta,
         ge_sec_contables sc
  where g.cod_persona = c.cod_persona
     and g.cod_garantia = tg.cod_garantia
     and g.cod_ent_escribania = e.cod_ente(+)
     and ta.cod_sec_contable = sc.cod_sec_contable(+)
     and t.cod_transaccion = tg.cod_transaccion2
     and t.cod_modalidad = 61
     and t.cod_tip_asiento = ta.cod_tip_asiento
     and ta.cod_moneda = g.cod_moneda
     and ta.tip_movimiento = 'D'
     and tg.cod_transaccion1 is null
     and g.estado <> 'N';

     -- se consulta cantidad de registros
     select count(*) into v_cant from inv_gar_tmp;

     -- redondeo por exceso parcheado
     v_paginas := round(v_cant/p_corte) + 1;

     V_NOM := p_archivo || '.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;

     --se inserta la cabecera
     V_CAB := q'[select 'referencia;rubro;des_asiento;oficina;sec_contable;res;cod_persona;cod_garantia;des_garantia;nro_garantia;estado_garantia;fec_inicio;fec_vencimiento;moneda;valor;val_tasacion;fec_ult_tasacion;nro_escritura;des_escribano;situacion;situacion_garantia' from dual]';

     prg_gen_archivo_txt(trim(V_NOM),V_CAB,'N',null,'N');

     --se inserta el detalle
     FOR v_cont IN 1 .. v_paginas
     LOOP
       V_SQL := 'select
       referencia  || CHR(59) ||
       rubro || CHR(59) ||
       des_asiento || CHR(59) ||
       oficina || CHR(59) ||
       sec_contable || CHR(59) ||
       res || CHR(59) ||
       cod_persona || CHR(59) ||
       cod_garantia || CHR(59) ||
       des_garantia || CHR(59) ||
       nro_garantia || CHR(59) ||
       estado_garantia || CHR(59) ||
       fec_inicio || CHR(59) ||
       fec_vencimiento || CHR(59) ||
       moneda || CHR(59) ||
       valor || CHR(59) ||
       val_tasacion || CHR(59) ||
       fec_ult_tasacion || CHR(59) ||
       nro_escritura || CHR(59) ||
       des_escribano || CHR(59) ||
       situacion || CHR(59) ||
       situacion_garantia
       from inv_gar_tmp
       where referencia between ' || v_ini || ' and ' || v_fin || ' order by referencia asc';

       prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');

       v_ini := v_fin + 1;
       v_fin := v_fin + p_corte;
       v_cont2 := v_cont2 + 1;
    END LOOP;

    commit;

    exception
       when others then
          raise_application_error('-20000','Error en PRP_GEN_INV_GARANTIAS'||sqlerrm);

end PRP_GEN_INV_GARANTIAS;

