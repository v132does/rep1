CREATE OR REPLACE PROCEDURE IT.PRP_GEN_CAR_SEG_VID_DISTR IS

-------------------------------------------------------------
--Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)------
--Generacion mensual registros de cargos, no se contabiliza--
-------------------------------------------------------------

-- Todos los préstamos vigente, con saldo de capital y seguro de vida
v_fec_actual      date :=PAG_CAL.FU_OBT_FEC_ACTUAL(6);
Cursor c_prestamos is
select distinct p.cod_modalidad,
                p.nro_cuenta,
                c.cod_transaccion,
                p.nro_solicitud
  from pr_sol_cargos c, pr_cta_prestamos p, ba_tab_dat_adicionales d
 where p.estado not in ('N', 'I') -- Prestamos vigentes, que no esten ni cancelados ni incobrables
   and nvl(p.sal_capital, 0) > 0
   and c.nro_solicitud = p.nro_solicitud
   and c.cod_transaccion = 1521
   and d.tab_relacion = 'PR_SOLICITUDES'
   and d.parametro = 'PRE_IND_CUO_CAL_SEGURO'
   and d.referencia = p.nro_solicitud
   and d.val_parametro = 'S'
   --Verifica si exists registro del desembolso--
   and exists (select 1 from pr_cta_gas_seguros y
                where y.nro_cuenta = p.nro_cuenta
                  and y.nro_cuota = 0
                  and y.estado = 'G')
   and exists (select 1 from pr_cta_gas_seguros z
                where z.nro_cuenta = p.nro_cuenta
                  and z.nro_cuota > 0
                  and z.fec_ini_vigencia <= v_fec_actual
                  and z.estado = 'I')
union
select distinct p.cod_modalidad,
                p.nro_cuenta,
                c.cod_Transaccion,
                p.nro_solicitud
  from pr_cta_gastos c, pr_cta_prestamos p, ba_tab_dat_adicionales d
 where p.estado not in ('N', 'I') -- Prestamos vigentes, que no esten ni cancelados ni incobrables
   and nvl(p.sal_capital, 0) > 0
   and c.nro_cuenta = p.nro_cuenta
   and c.cod_Transaccion = 1521 -- Cargo x seg de vida en cuotas
   and d.tab_relacion = 'PR_SOLICITUDES'
   and d.parametro = 'PRE_IND_CUO_CAL_SEGURO'
   and d.referencia = p.Nro_Solicitud
   and d.val_parametro = 'S'
   --Verifica si exists registro del desembolso--
   and exists (select 1 from pr_cta_gas_seguros y
                where y.nro_cuenta = p.nro_cuenta
                  and y.nro_cuota = 0
                  and y.estado = 'G')
   and exists (select 1 from pr_cta_gas_seguros z
                where z.nro_cuenta = p.nro_cuenta
                  and z.nro_cuota > 0
                  and z.fec_ini_vigencia <= v_fec_actual
                  and z.estado = 'I');
                  
--Variables generales--
v_importe         ge_movimientos.monto%type;
v_mto_seg_vida    ge_movimientos.monto%type;
v_nro_cuota       pr_cuotas.nro_cuota%type;
v_imp_cuota       number;
v_nro_cuo_gasto   pr_cta_gas_seguros.nro_cuota%type;
v_fec_vto         date;
v_redondeo        number(2);
v_tas_prima       ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_val_tas_prima   ge_movimientos.val_tasa%type;
v_ent_seguro      ge_entes.cod_ente%type;
v_cod_persona     ba_personas.cod_persona%type;
v_cod_tas_seg_vida ge_movimientos.cod_tasa%type;
v_lugar           varchar2(100);
v_dia_plazo       pr_solicitudes.dia_plazo%type;
v_fec_ini_vigencia date;

-- Variables de registro
r_pcpre           pr_cta_prestamos%rowtype;
r_gmovi           ge_movimientos%rowtype;
v_fec_ult_pago    date;
rg_calend         ge_calendarios%rowtype := pag_cal.fu_obt_reg_cal(6); ---DYDMR-7487 - 19/10/2017
v_fec_control     ge_calendarios.fec_actual%type;
v_cod_ref_gasto   pr_cta_gastos.cod_ref_gasto%type;

--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------
BEGIN
 ----- DYDMR-7487 - 19/10/2017 ---
 v_fec_control := v_fec_actual;
 if v_fec_actual = rg_calend.ult_dia_mes_habil then
    v_fec_control := RG_CALEND.ULT_DIA_MES;
 END IF;
 ---------------------------------
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
    For reg in c_prestamos loop
      v_imp_cuota := 0;
      v_importe := 0;
      v_nro_cuo_gasto := null;
      v_fec_ini_vigencia := null;
      v_cod_ref_gasto := null;
      r_gmovi := null;  --Inicializar registro movimiento
      v_lugar := 'Cta.: '||reg.nro_cuenta;
      --Traer los datos del prestamo
      pap_pre.pr_obt_dat_prestamo(reg.nro_cuenta, r_pcpre);
      -- Trae el codigo del ente que corresponde a la propuesta
      begin
         select t.cod_ent_seguro, c.monto, p.dia_plazo, c.nro_cuota,
                c.cod_tas_ref1, c.val_tas_ref1, c.cod_tas_ref2, c.val_tas_ref2,
                decode(c.nro_cuota,1,c.fec_ini_vigencia,c.fec_ini_vigencia+1)
           into v_ent_seguro, v_mto_seg_vida, v_dia_plazo, v_nro_cuo_gasto,
                v_cod_tas_seg_vida, v_val_tasa, v_tas_prima, v_val_tas_prima,
                v_fec_ini_vigencia
           from pr_sol_cargos t, pr_cta_gas_seguros c, pr_solicitudes p
          where t.nro_solicitud = reg.nro_solicitud
            and c.nro_solicitud = t.nro_solicitud
            and c.nro_solicitud = p.nro_solicitud
            and t.cod_transaccion = 1521
            and c.estado = 'I'
            and c.nro_cuota = (select min(x.nro_cuota)
                               from pr_cta_gas_seguros x
                               where x.nro_solicitud = t.nro_solicitud
                                 and x.estado = 'I'
                                 and x.fec_ini_vigencia <= v_fec_actual);
       exception
      when no_data_found then
         v_ent_seguro := FUG_OBT_ENT_SEGURO(6, reg.cod_modalidad, 'V');
          when others then
               raise_application_error(-20000,
                    'No encuentra código de Aseguradora. Verifique Solicitud '||reg.nro_solicitud);
        end;
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
       v_fec_ult_pago := null;
       v_imp_cuota := v_mto_seg_vida;
       v_fec_actual := v_fec_actual;
  
      --Traer el codigo de persona
      Begin
        v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
      Exception
        when others then
           v_cod_persona := null;
      end;
      
      -- Traer la fecha de vencimiento de la cuota mas vencida pendiente de pago
      Begin
        Select min(fec_vencimiento), min(nro_cuota) into v_fec_vto, v_nro_cuota
          from pr_cuotas
         where nro_cuenta = reg.nro_cuenta
           and fec_vencimiento > v_fec_control
           and estado <> 'N'
           and nro_cuota > 0;-- DYDMR-7487 - 19/10/2017
        --RI: 01/09/2010: Si la minima cuota esta vencida, asignar esa fecha de vto.
        If v_fec_vto is null then
          Select min(fec_vencimiento) into v_fec_vto
            from pr_cuotas
           where nro_cuenta = reg.nro_cuenta
             and estado <> 'N'
             and nro_cuota > 0;-- DYDMR-7487 - 19/10/2017
        End if;

      Exception
         when others then
           raise_application_error(-20000, 'Error en Generar Mov. Seguro al traer fecha de vencimiento de cuota. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
      End;
      
      --Obtener codigo de referencia de gasto--
       Select S_COD_REF_GASTO.NEXTVAL 
         into v_cod_ref_gasto 
         from dual;
         
      --Insertar los gastos correspondientes--
        Insert into Pr_cta_gastos a
          (Nro_cuenta, Cod_transaccion, cod_moneda, Monto, Fec_ingreso,
           Fec_ini_vigencia, Fec_vencimiento, fec_ult_pago, Cod_modalidad, cod_modulo, nro_solicitud,
           cod_tas_ref1, val_tas_ref1, cod_tas_ref2, val_tas_ref2, cod_ref_gasto)
        Values
          (r_pcpre.nro_cuenta, reg.cod_transaccion, r_pcpre.cod_moneda, v_imp_cuota, v_Fec_actual,
           v_fec_ini_vigencia, null, v_fec_ult_pago, r_pcpre.cod_modalidad, r_pcpre.cod_modulo,r_pcpre.nro_solicitud,
           v_cod_tas_seg_vida, v_val_tasa, v_tas_prima, v_val_tas_prima, v_cod_ref_gasto);
      
      --Modificar el registro que genero el cargo--
      update pr_cta_gas_seguros a
         set a.estado = 'G',
             a.cod_ref_gasto = v_cod_ref_gasto
       where a.nro_solicitud = reg.nro_solicitud
         and a.nro_cuota = v_nro_cuo_gasto;
       
       --- Siguiente registro
       <<siguiente_registro>>
       null;
    End loop;
    --Envia Avisos de Renovaciones--
    prl_env_mai_ren_seg_distr;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos por seguro de Vidas.'||' - '||v_lugar||' Error : '||sqlerrm);
END;
/

