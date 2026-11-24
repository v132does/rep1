create or replace PROCEDURE       IT.PRB_GEN_PRE_CIERRE is
v_fec_anterior pre_cierre_tmp.fecha%TYPE := pag_cal.FU_OBT_FEC_ANTERIOR(6);
p_archivo varchar2(100) := 'PRE_CIERRE_'||TO_CHAR(v_fec_anterior,'YYYYMMDD');
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

/*02/01/2026 MJ - TN815  Se modifica forma de envio por ftp del reporte, se comentan lineas de corte de 10000 y paginado ya que esta haciendo el envio al servidor de forma
                         incremental y esto genera N cantidad de envios, evidenciandose errores deposito en produccion, se modifica la estructura para que se haga un solo envio*/

begin
     --Se limpia la tabla temporal
     --delete from pre_cierre_tmp;
     execute immediate 'truncate table pre_cierre_tmp';
  declare
  cursor tra_padre is
     select b.cod_tra_padre ,
            b.cod_mod_padre,
            b.cod_mad_padre
     from ge_asientos_tmp  b
     where b.fecha = v_fec_anterior
      and b.usu_insercion in (select val_minimo
                                from ba_cod_referencias
                               where dominio = 'USU_CIERRE')
    having(sum(decode(b.tip_mov_rubro, 'D', b.mto_equ_local, 0)) - sum(decode(b.tip_mov_rubro, 'C', b.mto_equ_local, 0))) <> 0
    group by b.cod_tra_padre , b.cod_mod_padre, b.cod_mad_padre
    order by b.cod_tra_padre;
 begin
  for reg in tra_padre
  loop
   insert into pre_cierre_tmp (
       fecha,
       hora,
       cod_usuario,
       cod_ofi_origen,
       nro_secuencia,
       nro_cuenta,
       cod_moneda,
       monto,
       mto_en_gs,
       cod_tra_padre,
       cod_mod_padre,
       cod_mad_padre,
       nro_documento,
       desc_tra_padre,
       cod_modalidad,
       cod_transaccion,
       desc_tra_hijo,
       tip_mov_rubro,
       rubro_contable,
       desc_rubro,
       mto_asiento,
       debito,
       credito,
       observacion,
       referencia,
       cod_rub_externo)
     select
       b.fecha,
       ' '||b.hora,
       b.cod_usuario,
       b.cod_ofi_origen,
       b.nro_secuencia,
       b.nro_cuenta,
       b.cod_moneda,
       b.monto,
       b.mto_equ_local,
       b.cod_tra_padre,
       b.cod_mod_padre,
       b.cod_mad_padre,
       b.nro_documento,
       c.descripcion,
       b.cod_modalidad,
       b.cod_transaccion,
       d.descripcion,
       b.tip_mov_rubro,
       substr(b.cod_rubro,1,2)||'.'||substr(b.cod_rubro,3,1)||'.'||
       substr(b.cod_rubro,4,2)||'.'||substr(b.cod_rubro,6,3)||'.'||
       substr(b.cod_rubro,3,1)||'.'||substr(b.cod_rubro,9,2)||'.'||
       substr(b.cod_rubro,11,3)||'.'||substr(b.cod_rubro,14,2),
       x.descripcion,
       b.monto,
       decode(b.tip_mov_rubro,'D',b.mto_equ_local,0),
       decode(b.tip_mov_rubro,'C',b.mto_equ_local,0),
       b.observacion,
       rownum,
       x.cod_rub_externo
     from cb_rubros x, ge_transacciones d, ge_transacciones c, ge_asientos_tmp  b
     where b.cod_mod_padre = c.cod_modulo(+)
     and b.cod_mad_padre = c.cod_modalidad(+)
     and b.cod_tra_padre = c.cod_transaccion(+)
     and b.cod_modulo = d.cod_modulo(+)
     and b.cod_modalidad = d.cod_modalidad(+)
     and b.cod_transaccion = d.cod_transaccion(+)
     and x.cod_rubro(+) = b.cod_rubro
     and b.fecha = v_fec_anterior
     and b.cod_tra_padre = reg.cod_tra_padre
     and b.cod_mod_padre = reg.cod_mod_padre
     and b.cod_mad_padre = reg.cod_mad_padre
     and b.usu_insercion in (select val_minimo
                                from ba_cod_referencias
                               where dominio = 'USU_CIERRE')
     order by hora;
  end loop;
 end;
     -- se consulta cantidad de registros
     -- select count(*) into v_cant from pre_cierre_tmp; 

     -- redondeo por exceso parcheado
     -- v_paginas := round(v_cant/p_corte) + 1;

     V_NOM := p_archivo || '.TXT';
     /*v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;*/

     --se inserta la cabecera
     V_CAB := q'[select 'referencia;fecha;hora;cod_usuario;cod_ofi_origen;nro_secuencia;nro_cuenta;cod_moneda;monto;mto_en_gs;cod_tra_padre;desc_tra_padre;cod_modalidad;cod_transaccion;desc_tra_hijo;tip_mov_rubro;rubro_contable;cod_rub_externo;desc_rubro;mto_asiento;debito;credito;observacion;cod_mod_padre;cod_mad_padre;nro_documento;' from dual]';

     prg_gen_archivo_txt(trim(V_NOM),V_CAB,'N',null,'N');

     --se inserta el detalle
    /* FOR v_cont IN 1 .. v_paginas
     LOOP*/
       V_SQL := 'select
       referencia || CHR(59) ||
       fecha || CHR(59) ||
       hora || CHR(59) ||
       cod_usuario || CHR(59) ||
       cod_ofi_origen || CHR(59) ||
       nro_secuencia || CHR(59) ||
       nro_cuenta || CHR(59) ||
       cod_moneda || CHR(59) ||
       monto || CHR(59) ||
       mto_en_gs || CHR(59) ||
       cod_tra_padre || CHR(59) ||
       desc_tra_padre || CHR(59) ||
       cod_modalidad || CHR(59) ||
       cod_transaccion || CHR(59) ||
       desc_tra_hijo || CHR(59) ||
       tip_mov_rubro || CHR(59) ||
       rubro_contable || CHR(59) ||
       cod_rub_externo || CHR(59) ||
       desc_rubro || CHR(59) ||
       mto_asiento || CHR(59) ||
       debito || CHR(59) ||
       credito || CHR(59) ||
       observacion   || CHR(59) ||
       cod_mod_padre || CHR(59) ||
       cod_mad_padre || CHR(59) ||
       nro_documento
       from pre_cierre_tmp';
       --where referencia between ' || v_ini || ' and ' || v_fin || ' order by referencia asc';

       prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');

       /*v_ini := v_fin + 1;
       v_fin := v_fin + p_corte;
       v_cont2 := v_cont2 + 1;
    END LOOP;*/

    commit;

    exception
       when others then
          raise_application_error('-20000','Error en PRB_GEN_PRE_CIERRE'||sqlerrm);

end PRB_GEN_PRE_CIERRE;
/