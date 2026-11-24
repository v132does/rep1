create or replace procedure it.PRB_CUA_AUT_INV is
   --- Realiza apuntes de cuadre automático de Inventarios
   --- Realizado por: Ingrid Larraín - 26/09/2011
   --- Propiedad exclusiva del BBVA
   --------------------------------------------------------
   --- Cursor de rubros a cuadrar
   Cursor c_diferencias is
   select cod_rubro, cod_oficina, cod_moneda, tot_inventario, sal_contable, diferencia
     from CB_ASI_CUADRES_TMP
    where nvl(diferencia,0) <> 0
    order by cod_oficina; -- Solo tomar rubros con diferencias

   --- Variables auxiliares
   v_cod_rub_cuadre   cb_rubros.cod_rubro%type;
   v_cod_rub_inter    cb_rubros.cod_rubro%type;
   v_cod_rub_boleteo  cb_rubros.cod_rubro%type;
   v_cod_ofi_ant      ba_oficinas.cod_oficina%type := null;
   v_fec_actual       ge_calendarios.fec_actual%type;
   v_nro_asiento      cb_asi_futuros.nro_asiento%type := 0;
   v_nro_asiento_31   cb_asi_futuros.nro_asiento%type := 0;
   v_tot_control      cb_asi_futuros.tot_control%type := 0;
   v_nro_linea        cb_asi_futuros.nro_asi_real%type;
   v_nro_linea_31     cb_asi_futuros.nro_asi_real%type;
   v_val_cotizacion   ge_cotizaciones.val_conversion%type;
   v_cod_mon_local    ba_monedas.cod_moneda%type;
   v_cod_mon_util     ba_monedas.cod_moneda%type;
   v_tip_movimiento   cb_asi_futuros_det.tip_movimiento%type;
   v_sal_contable     cb_sal_oficinas.sal_mon_loc_ant%type;
   v_diferencia       cb_sal_oficinas.sal_mon_loc_ant%type;
   v_naturaleza       cb_rubros.naturaleza%type;
   v_est_modulo       ba_modulos.estado%type;

   --- Cursor de oficina 31 para boletear
   Cursor c_boleteo is
   select r.cod_moneda,
          sum(decode(d.tip_movimiento,'C',d.mto_mon_rubro*-1,d.mto_mon_rubro)) neto, --Negativo es el crédito mayor
          sum(decode(d.tip_movimiento,'C',d.mto_mon_local*-1,d.mto_mon_local)) neto_ml
     from cb_asi_futuros_det d, cb_asi_futuros f, cb_rubros r
    where d.fecha=f.fecha
      and d.nro_asiento=f.nro_asiento
      and d.cod_rubro=r.cod_rubro
      and d.fecha=v_fec_actual
      and f.nro_asiento=v_nro_asiento_31
    group by r.cod_moneda
    having sum(decode(d.tip_movimiento,'C',d.mto_mon_local*-1,d.mto_mon_local)) <> 0;

   --- Recupera rubro de boleteo
   FUNCTION lf_rec_rub_boleteo(p_cod_moneda in varchar2)
   return varchar2 is
      v_cod_rub_boleteo  cb_rubros.cod_rubro%type;
    begin
       select g.cod_rubro into v_cod_rub_boleteo
         from cb_gru_rubros_det g, cb_rubros r
        where cod_gru_rubro = 7
          and g.cod_rubro = r.cod_rubro
          and r.cod_moneda = p_cod_moneda;
       return v_cod_rub_boleteo;
    exception
       when no_data_found then
          raise_application_error(-20000,
          'No existe rubro boleteo para moneda '||p_cod_moneda);
       when others then
          raise_application_error(-20000,
          'Al recup. rub. boleteo '||sqlerrm);
    end;


begin
   --- Validar que el módulo 2 esté cerrado
   begin
      select estado into v_est_modulo
        from ba_modulos
       where cod_modulo=2;
   exception
      when no_data_found then
         raise_application_error(-20000,'Estado del modulo no pudo recuperarse');
   end;
   if v_est_modulo <> 4 then
      raise_application_error(-20000,'Módulo debe estar cerrado para procesar asientos de cuadre');
   end if;
   v_fec_actual := pag_cal.fu_obt_fec_actual(2);
   --- Recuperar el rubro contra el cual se debe cuadrar
   begin
      select t.cod_rubro, r.cod_moneda
        into v_cod_rub_cuadre, v_cod_mon_util
        from cb_asi_cuadres_tmp t, cb_rubros r
       where nvl(diferencia,0)=0
         and t.cod_rubro=r.cod_rubro;
   exception
      when no_data_found then
          raise_application_error(-20000,'Rubro de cuadre no registrado');
      when too_many_rows then
          raise_application_error(-20000,'Rubro de cuadre duplicado');
   end;
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   --- Crear asiento cabecera para oficina 31 ---
   v_nro_asiento_31 := fub_obt_sig_nro_asi_futuro(31, v_fec_actual);
   v_nro_linea_31   := 0;
   INSERT INTO cb_asi_futuros
       (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo,
        tot_control)
   VALUES
        (v_fec_actual, 31, v_nro_asiento_31, USER, 2, 21, null,
        0); -- Mientras, se actualizará al final.
   for reg in c_diferencias loop
      if v_cod_ofi_ant is null --- Corte de control de oficina
      or v_cod_ofi_ant <> reg.cod_oficina then
         --- Actualizar total control de la cabecera
         if v_cod_ofi_ant is not null then
            update cb_asi_futuros
               set tot_control = v_tot_control
             where cod_oficina = v_cod_ofi_ant
               and nro_asiento = v_nro_asiento
               and fecha=v_fec_actual;
         end if;
         --- Recupero último asiento futuro de la oficina para la fecha actual
         v_nro_asiento := fub_obt_sig_nro_asi_futuro(reg.cod_oficina, v_fec_actual);
         --- Insertar cabecera del asiento
         INSERT INTO cb_asi_futuros
             (fecha, cod_oficina, nro_asiento, cod_usuario, cod_modulo, cod_modalidad, cod_cargo,
              tot_control)
         VALUES
              (v_fec_actual, reg.cod_oficina, v_nro_asiento, USER, 2, 21, null,
              0); -- Mientras, se actualizará al final.
         --- Inicializo variables de corte de control
         v_cod_ofi_ant := reg.cod_oficina;
         v_tot_control := 0;
         v_nro_linea   := 0;
      end if;
      v_val_cotizacion := null;
      if reg.cod_moneda <> v_cod_mon_local then
         v_val_cotizacion := fug_obt_cotizacion(reg.cod_moneda,v_fec_actual);
      end if;
      --- APUNTE POR RUBRO DESCUADRADO
      --- Recuperar saldo contable del rubro
      begin
         select decode(reg.cod_moneda,v_cod_mon_local,
                nvl(o.sal_mon_loc_ant,0)+nvl(o.deb_mon_local,0)-nvl(o.cre_mon_local,0),
                nvl(o.sal_mon_rub_ant,0)+nvl(o.deb_mon_rubro,0)-nvl(o.cre_mon_rubro,0)),
                r.naturaleza
           into v_sal_contable, v_naturaleza
           from cb_sal_oficinas o, cb_rubros r
          where o.cod_rubro = reg.cod_rubro
            and r.cod_rubro = o.cod_rubro
            and o.cod_oficina = reg.cod_oficina;
      exception
         when no_data_found then
            v_sal_contable := 0; -- Por si no tenga saldo actualmente pero debe tener
      end;
      --- Verificar tipo de movimiento
      if v_sal_contable = reg.sal_contable
      and v_sal_contable <> 0 then
         --- El saldo contable no fue cambiado de naturaleza para el cuadre, respetar signo de diferencia
         if reg.diferencia < 0 then -- tengo mas inventario
            v_tip_movimiento := 'C';
         else
            v_tip_movimiento := 'D';
         end if;
      elsif v_sal_contable <> 0 then
         v_diferencia := reg.diferencia * -1;
         if v_diferencia < 0 then -- tengo mas saldo contable
            v_tip_movimiento := 'C';
         else
            v_tip_movimiento := 'D';
         end if;
      else --- Para saldo contable = 0, debo analizar la naturaleza de la cuenta
         --- En ITGF: + = Deudor, - = Acreedor
         if v_naturaleza = '-' then -- Acreedor, saldo debe ser negativo
            v_diferencia := reg.diferencia * -1;
            if v_diferencia < 0 then -- tengo mas saldo contable
               v_tip_movimiento := 'C';
            else
               v_tip_movimiento := 'D';
            end if;
         end if;
      end if;
      v_nro_linea := v_nro_linea + 1;
      v_tot_control := nvl(v_tot_control,0) + fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,abs(reg.diferencia));
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
          tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fec_actual, reg.cod_oficina, v_nro_asiento, v_nro_linea, reg.cod_rubro,
          v_tip_movimiento, fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,abs(reg.diferencia)),
          'Asiento Automatico Cuadre Balance vs Inventario', decode(reg.cod_moneda,v_cod_mon_local,0,abs(reg.diferencia)),
           v_val_cotizacion);
      --- APUNTE INTEROFICINA EN LA MONEDA DEL RUBRO
      --- Recuperar rubro interoficina para la moneda
      v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                             reg.cod_moneda, reg.cod_oficina);
      v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(31, '000')) ||
                              substr(v_cod_rub_inter, 14, 2);
      if v_tip_movimiento = 'D' then
         v_tip_movimiento := 'C';
      else
         v_tip_movimiento := 'D';
      end if;
      v_nro_linea   := v_nro_linea + 1;
      v_tot_control := nvl(v_tot_control,0) + fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,abs(reg.diferencia));
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fec_actual, reg.cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_inter,
          v_tip_movimiento, fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,abs(reg.diferencia)),
          'Asiento Automatico Cuadre Balance vs Inventario', decode(reg.cod_moneda,v_cod_mon_local,0,abs(reg.diferencia)),
           v_val_cotizacion);
      --- APUNTE EN OFICINA DESTINO -- 31
      --- Recuperar rubro interoficina para la moneda
      v_cod_rub_inter := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                             reg.cod_moneda, 31);
      v_cod_rub_inter :=  substr(v_cod_rub_inter, 1, 10) || ltrim(to_char(reg.cod_oficina, '000')) ||
                              substr(v_cod_rub_inter, 14, 2);
      if v_tip_movimiento = 'C' then
         v_tip_movimiento := 'D';
      else
         v_tip_movimiento := 'C';
      end if;
      v_nro_linea_31 := v_nro_linea_31 + 1;
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fec_actual, 31, v_nro_asiento_31, v_nro_linea_31, v_cod_rub_inter,
          v_tip_movimiento, fub_con_mon_a_moneda(reg.cod_moneda,v_cod_mon_local,abs(reg.diferencia)),
          'Asiento Automatico Cuadre Balance vs Inventario', decode(reg.cod_moneda,v_cod_mon_local,0,abs(reg.diferencia)),
           v_val_cotizacion);
   end loop;
   --- Actualizar total control de la cabecera del último registro leido
   if v_cod_ofi_ant is not null then
      update cb_asi_futuros
         set tot_control = v_tot_control
       where cod_oficina = v_cod_ofi_ant
         and nro_asiento = v_nro_asiento
         and fecha=v_fec_actual;
   end if;
   --- Neteo oficina 31 para boletear
   for bol in c_boleteo loop
      v_val_cotizacion := null;
      if bol.cod_moneda <> v_cod_mon_local then
         v_val_cotizacion := fug_obt_cotizacion(bol.cod_moneda,v_fec_actual);
      end if;
      --- Verifico tipo de movimiento
      if bol.neto_ml < 0 then
         v_tip_movimiento := 'D';
      else
         v_tip_movimiento := 'C';
      end if;
      v_nro_linea_31 := v_nro_linea_31 + 1;
      --- Inserto asiento de utilidad
      INSERT INTO cb_asi_futuros_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
          descripcion, mto_mon_rubro, val_cotizacion)
      VALUES
         (v_fec_actual, 31, v_nro_asiento_31, v_nro_linea_31, v_cod_rub_cuadre,
          v_tip_movimiento, abs(bol.neto_ml),
          'Asiento Automatico Cuadre Balance vs Inventario', 
           decode(v_cod_mon_util,v_cod_mon_local,0,fub_con_mon_a_moneda(v_cod_mon_local,v_cod_mon_util,abs(bol.neto_ml))),
           v_val_cotizacion);
      if bol.cod_moneda <> v_cod_mon_local then -- Solo para monedas extranjeras
         --- Inserto asiento de boleteo ME
         v_nro_linea_31 := v_nro_linea_31 + 1;
         v_cod_rub_boleteo := lf_rec_rub_boleteo(bol.cod_moneda);
         INSERT INTO cb_asi_futuros_det
            (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
             descripcion, mto_mon_rubro, val_cotizacion)
         VALUES
            (v_fec_actual, 31, v_nro_asiento_31, v_nro_linea_31, v_cod_rub_boleteo,
             v_tip_movimiento, abs(bol.neto_ml),
             'Asiento Automatico Cuadre Balance vs Inventario', decode(bol.cod_moneda,v_cod_mon_local,0,abs(bol.neto)),
              v_val_cotizacion);
         --- Insertar rubro boleteo de Moneda local
         --- Verifico tipo de movimiento
         if v_tip_movimiento = 'C' then
            v_tip_movimiento := 'D';
         else
            v_tip_movimiento := 'C';
         end if;
         v_nro_linea_31 := v_nro_linea_31 + 1;
         v_cod_rub_boleteo := lf_rec_rub_boleteo(v_cod_mon_local);
         INSERT INTO cb_asi_futuros_det
            (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_local,
             descripcion, mto_mon_rubro, val_cotizacion)
         VALUES
            (v_fec_actual, 31, v_nro_asiento_31, v_nro_linea_31, v_cod_rub_boleteo,
             v_tip_movimiento, abs(bol.neto_ml),
             'Asiento Automatico Cuadre Balance vs Inventario',0, null);
      end if;
   end loop;
   --- Actualizar total control para oficina 31
   update cb_asi_futuros f
      set tot_control = (select sum(e.mto_mon_local)
                          from cb_asi_futuros_det e
                          where f.nro_asiento=e.nro_asiento
                            and e.cod_oficina=f.cod_oficina
                            and e.cod_oficina=31
                            and e.nro_asiento=v_nro_asiento_31
                            and fecha=v_fec_actual)
    where nro_asiento=v_nro_asiento_31
      and cod_oficina=31
      and fecha=v_fec_actual;
end PRB_CUA_AUT_INV;
/

