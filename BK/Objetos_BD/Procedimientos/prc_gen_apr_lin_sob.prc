create or replace procedure it.PRC_GEN_APR_LIN_SOB is
v_nro_sec_inicial cc_lin_sobregiros.nro_secuencia%type;
v_nro_secuencia   cc_lin_sobregiros.nro_sec_padre%type;
v_fec_actual      date := pae_cnf.FU_OBT_FEC_ACTUAL(4);
v_cotizacion      cc_lin_sobregiros.cotizacion%type;
v_dia_max         number(4) := fug_obt_pardinamico('CAN_DIA_MAXIMO');
v_fecha           date;
v_error           cc_lin_sob_tmp.det_error%type;
v_errores         varchar2(1);
v_estado          varchar2(1);
v_tie_cuenta      varchar2(1);
v_exi_cod_rub_eco varchar2(1);
v_tip_persona     ba_personas.tipo%type;
v_cod_campanas    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAM_REN_LIN_SOB');
v_cod_rub_eco_ren ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_RUB_ECO_REN_LIN_SOB');
cursor c_lin_sobregiros is
  select *
    from cc_lin_sob_tmp a;
begin
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  v_cotizacion := pag_gen.fu_obt_cotizacion(pag_gen.FU_OBT_MON_FUERTE,v_fec_actual);
  for lin in c_lin_sobregiros loop
    v_error  := null;
    v_estado := null;
    begin
      select 'S'
        into v_tie_cuenta
        from ge_cta_clientes a,cc_cta_corrientes c
       where a.cod_persona = lin.cod_persona
         and a.nro_cuenta = lin.nro_cuenta
         and a.relacion = 'P'
         and a.nro_cuenta = c.nro_cuenta
         and a.cod_modulo = c.cod_modulo
         and a.cod_modalidad = c.cod_modalidad
         and c.estado != 'C';
    exception
      when no_data_found then
        v_tie_cuenta := 'N';
      when too_many_rows then
        v_tie_cuenta := 'S';
    end;
    if v_tie_cuenta = 'N' then
       v_error := 'El cliente no posee Cuenta Corriente. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;
    begin
      select a.estado
        into v_estado
        from cc_lin_sobregiros a
       where a.cod_persona in lin.cod_persona
         and a.estado != 'V';
    exception
      when no_data_found then
        v_estado := null;--no tiene linea de sobregiro
    end;
    if v_estado is not null then
       v_error := 'El cliente ya cuenta con linea de sobregiro estado '||v_estado||'. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;

    v_fecha := lin.fec_inicio + v_dia_max;
    if lin.fec_vencimiento  > v_fecha then
       --raise_application_error(-20000, 'Fecha de vencimiento no debe superar los '||to_char(v_dia_max+1)||' días');
       v_error := v_error||'Fecha de vencimiento no debe superar los '||to_char(v_dia_max+1)||' días. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;
    if lin.fec_vencimiento < v_fec_actual then
	 	 	 --raise_application_error(-20001,'Fecha de Vencimiento no debe ser menor a hoy');
       v_error := v_error||'Fecha de Vencimiento no debe ser menor a hoy. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;
    if nvl(lin.monto,0) = 0 then
       --raise_application_error(-20002, 'Debe ingresar el monto de la linea');
       v_error := v_error||'Debe ingresar el monto de la linea. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;
    begin
      select tipo
        into v_tip_persona
        from ba_personas
       where cod_persona = lin.cod_persona;
    exception
      when others then
        v_tip_persona := 'X';
    end;
    if instr(','|| v_cod_campanas ||',' ,  ','||lin.cod_campana||',') > 0
       and lin.cod_rub_economico is null and v_tip_persona = 'F' and lin.tipo = 'T' then
       v_error := v_error||'Debe insertar el Rubro Economico. ';
       update cc_lin_sob_tmp a
          set a.det_error = v_error
        where a.nro_cuenta = lin.nro_cuenta
          and a.cod_persona = lin.cod_persona;
          commit;
    end if;
    if lin.cod_rub_economico is not null then
       if instr(','|| v_cod_rub_eco_ren ||',' ,  ','||lin.cod_rub_economico||',') = 0 and instr(','|| v_cod_campanas ||',' ,  ','||lin.cod_campana||',') > 0
       and v_tip_persona = 'F' and lin.tipo = 'T' then
          v_error := v_error||'El Rubro económico debe ser de Consumo. ';
          update cc_lin_sob_tmp a
              set a.det_error = v_error
            where a.nro_cuenta = lin.nro_cuenta
              and a.cod_persona = lin.cod_persona;
          commit;
       end if;
       begin
         select distinct 'S'
           into v_exi_cod_rub_eco
           from pr_rub_economicos
          where cod_rub_economico = lin.cod_rub_economico;
       exception
         when others then
           v_exi_cod_rub_eco := 'N';
       end;
       if nvl(v_exi_cod_rub_eco, 'N') = 'N' then
          v_error := v_error||'No se encuentra el Rubro Economico. ';
          update cc_lin_sob_tmp a
              set a.det_error = v_error
            where a.nro_cuenta = lin.nro_cuenta
              and a.cod_persona = lin.cod_persona;
          commit;
        end if;
    end if;

    if v_error is null then
      begin
        select S_NRO_LIN_SOBREGIRO.nextval
          into v_nro_sec_inicial
          from dual;
      exception
        when no_data_found then
          v_nro_sec_inicial := 0;
      end;
      --insertar cabecera
      insert into cc_lin_sobregiros
        (fec_vencimiento,fec_inicio,nro_secuencia,monto,tipo,cod_persona,cod_moneda,estado,
         observacion,cod_rub_economico,cod_campana)
      values
        (lin.fec_vencimiento,lin.fec_inicio,v_nro_sec_inicial,lin.monto,lin.tipo,lin.cod_persona,lin.cod_moneda,'A',
         'Carga Masiva Campaña Sobregiro',nvl(lin.cod_rub_economico, 970792),lin.cod_campana);
      -- Requerimiento: CNFNORMA-173
      -- Fecha: 15/11/2016
      insert into ba_tab_dat_adicionales
              (tab_relacion, referencia, parametro, val_parametro)
          values
              ('CC_LIN_SOBREGIROS', v_nro_sec_inicial, 'PUN_SCORING', ltrim(rtrim(to_char(lin.pun_scoring,'99G999G990D999999999'))));
       -- Requerimiento: CNFNORMA-173
       -- Fecha: 15/11/2016
            insert into ba_tab_dat_adicionales
              (tab_relacion, referencia, parametro, val_parametro)
          values
              ('CC_LIN_SOBREGIROS', v_nro_sec_inicial, 'PRO_MORA', ltrim(rtrim(to_char(lin.pro_mora,'99G999G990D999999999'))));

       ----
      select S_NRO_LIN_SOBREGIRO.nextval
        into v_nro_secuencia
        from dual;
      --insertar detalle
      insert into cc_lin_sobregiros
        (nro_cuenta,fec_vencimiento,fec_inicio,nro_secuencia,monto,tipo,cod_moneda,estado,
         nro_sec_padre,cotizacion,observacion)
      values
        (lin.nro_cuenta,lin.fec_vencimiento,lin.fec_inicio,v_nro_secuencia,lin.monto,lin.tipo,lin.cod_moneda,'A',
         v_nro_sec_inicial,v_cotizacion,'Carga Masiva Campaña Sobregiro');

      prc_ins_his_sobregiro(v_nro_sec_inicial);
      commit;
    else -- existen errores
      v_errores := 'S';
    end if;
  end loop;
  --** Elimina los registros de la tabla temporal **--
  begin
    delete cc_lin_sob_tmp a
     where a.det_error is null;
     commit;
  exception
     when others then
        raise_application_error(-20060, 'Error al eliminar registros de CC_LIN_SOB_TMP '||SQLERRM);
  end;
  if v_errores = 'S' then
    RAISE_APPLICATION_ERROR(-20000,'Archivo contiene errores. Verifique. ');
  end if;
end PRC_GEN_APR_LIN_SOB;
/

