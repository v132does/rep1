create or replace procedure it.prb_gen_arc_rg90 is

p_tipo_registro varchar2(1):= fug_obt_pardinamico('RES_90_TIP_REG');--parametro para la creacion de tipos de archivos diferentes
V_RUC VARCHAR2(10);
V_PERIODO VARCHAR2(7);
V_FEC_ACTUAL ge_calendarios.fec_actual%type;
P_FECHA ge_calendarios.fec_actual%type;
v_cant_reg NUMBER:=0;
v_cant_arc NUMBER:=0;
v_nro_factura number;
v_error VARCHAR2(4000);
V_LIN_MAX_RG90 NUMBER:=0;
v_archivo       UTL_FILE.FILE_TYPE;
v_nombre     VARCHAR2(100);
v_directorio VARCHAR2(1000):= fug_obt_pardinamico('RES_90_DIRECT');--'/oradata/utl';--ramail/amaral

   cursor detalle is

    Select t.tipo_registro||';'||t.cod_tip_documento||';'||t.nro_identificador||';'||t.raz_social||';'||
           t.cod_tipo_comprobante||';'||to_char(t.fecha_emision,'dd/mm/yyyy')||';'||t.nro_timbrado||';'||t.nro_comprobante||';'||
           t.monto_gravado_10||';'||t.monto_gravado_5||';'||t.monto_exento||';'||t.monto_total||';'||
           t.condicion||';'||t.moneda_extranjera||';'||t.imputa_iva||';'||t.imputa_ire||';'||t.imputa_irp_rsp||';'||
           decode(t.tipo_registro,'2',t.no_imputa||';'||t.factura_asociada||';'||t.timbrado_asociado,
                  t.factura_asociada||';'||t.timbrado_asociado) linea, t.rowid
    From   cb_rg_90 t
    where  t.periodo = v_periodo
    and    t.tipo_registro = p_tipo_registro or p_tipo_Registro = '0'
    and    nvl(t.generado,'N') <> 'S'
    and    rownum <= V_LIN_MAX_RG90
    order  by tipo_Registro, t.fecha_emision;
begin
  NULL;
      select substr(fug_obt_pardinamico('RUC_ENTIDAD_LEGACY'),1,instr(fug_obt_pardinamico('RUC_ENTIDAD_LEGACY'),'-')-1)
      into V_RUC
      from dual;

      V_FEC_ACTUAL:= FUE_OBT_FEC_CALENDAR(1);
      --busca mes vencido--
      SELECT TRUNC(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM'), to_char(TRUNC(ADD_MONTHS(V_FEC_ACTUAL,-1),'MM'),'MMYYYY')
      INTO   P_FECHA, V_PERIODO
      FROM DUAL;
        Begin
          update cb_rg_90 t
          set    t.generado = 'N'
          where  t.periodo  =to_char(P_FECHA,'MM/YYYY');
          commit;
        end;
      Select count(*)
      into v_cant_reg
      from cb_rg_90;
      V_LIN_MAX_RG90 := fug_obt_pardinamico('RES_90_LIN_MAX');
      if ceil(v_cant_reg / V_LIN_MAX_RG90) > 1 then
         v_cant_arc := ceil(v_cant_reg / V_LIN_MAX_RG90);
      else
         v_cant_arc := 1;
      end if;
      for i in 1..v_cant_arc loop
		 v_nombre :=V_RUC||'_REG_'||to_char(P_FECHA,'MMYYYY')||'_1'||lpad(i,4,'0')||'.csv' ;
         v_archivo := pag_arc.fu_arc_abrir( v_directorio,v_nombre , 'w' );
         for j in detalle loop
            pag_arc.pr_arc_escribir(J.LINEA, v_archivo);

            update CB_RG_90 g
            set g.generado  = 'S'
            where g.rowid = j.rowid
            and nvl(generado,'N') = 'N';
         end loop;
         pag_arc.pr_arc_cerrar( v_archivo );
      end loop;
	  commit;
END;
/

