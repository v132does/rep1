CREATE OR REPLACE PACKAGE BODY IT.paa_ret IS

  --Proceso inserción retenciones Ley 6380 - INR
  procedure pr_ins_ge_inr_retenciones(pg_dret     ge_inr_retenciones%rowtype,
                                      p_cod_error in out varchar2) is

    --Variables
    rg_inr          ge_inr_retenciones%rowtype := pg_dret;
    v_cod_error     varchar2(2) := '00';
    v_cod_retencion ge_inr_retenciones.cod_retencion%type;

  begin

    select s_cod_retencion.nextval into v_cod_retencion from dual;

    insert into ge_inr_retenciones
      (cod_persona,
       nro_cuenta,
       fec_pago,
       nro_factura,
       mto_factura,
       cod_moneda,
       cod_retencion,
       mto_retencion,
       estado,
       cotizacion,
       mto_renta,
       mto_ret_renta,
       tipo_ret,
       nro_cupon,
       fecha,
       hora,
       cod_usuario,
       nro_secuencia,
       fec_retencion,
       nro_cta_credito,
       por_retencion)
    values
      (rg_inr.cod_persona,
       rg_inr.nro_cuenta,
       rg_inr.fec_pago,
       rg_inr.nro_factura,
       rg_inr.mto_factura,
       rg_inr.cod_moneda,
       v_cod_retencion,
       rg_inr.mto_retencion,
       rg_inr.estado,
       rg_inr.cotizacion,
       rg_inr.mto_renta,
       rg_inr.mto_ret_renta,
       rg_inr.tipo_ret,
       rg_inr.nro_cupon,
       rg_inr.fecha,
       rg_inr.hora,
       rg_inr.COD_USUARIO,
       rg_inr.NRO_SECUENCIA,
       rg_inr.fec_retencion,
       rg_inr.Nro_Cta_Credito,
       rg_inr.por_retencion);
    p_cod_error := v_cod_error;

  exception
    when others then
      v_cod_error := '01';
      p_cod_error := v_cod_error;
  end;

  --Proceso Generación de Retenciones INR Ahorros
  procedure pr_gen_inr_ret_ahorros(p_fec_pago      ge_inr_retenciones.fec_pago%type default null,
                                   p_nro_secuencia in out ge_movimientos.Nro_Secuencia%type,
                                   p_mto_retencion in out ge_inr_retenciones.mto_retencion%type,
                                   p_nro_cuenta    ge_inr_retenciones.nro_cuenta%type default null,
                                   p_cod_modulo    ge_cuentas.cod_modulo%type default null,
                                   p_cod_modalidad ge_cuentas.cod_modalidad%type default null) is

    v_fec_actual      ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(3);
    v_cod_modulo      ge_movimientos.cod_modulo%type := p_cod_modulo;
    v_cod_modalidad   ge_movimientos.cod_modalidad%type := p_cod_modalidad;
    v_cod_transaccion ge_transacciones.cod_transaccion%type := 609;
    v_redondeo        number(5);
    v_por_ret_inr   number;

    Cursor c_dat_int_ahorros is
      select g.cod_persona,
             h.nro_cuenta,
             h.cod_moneda,
             h.fecha,
             h.cod_oficina,
             sum(h.mto_interes) mto_interes,
             m.hora,
             m.cod_usuario,
             m.nro_secuencia
        from ah_capitalizaciones h,
             ge_cta_clientes     g,
             ge_clientes         e,
             ge_movimientos      m
       where h.nro_cuenta = g.nro_cuenta
         and h.cod_modulo = g.cod_modulo
         and h.cod_modalidad = g.cod_modalidad
         and m.fecha =
             pag_cal.fu_obt_fec_ant_hab(h.FECHA, m.cod_oficina, 0)
         and g.relacion = 'P'
         and g.cod_persona = e.cod_persona
         and e.residente = 'N'
         and h.mto_interes > 0 --DYDMR-13592
         and m.fecha = nvl(p_fec_pago, v_fec_actual)
         and ((p_nro_cuenta is not null and h.nro_cuenta = p_nro_cuenta) or
             (p_nro_cuenta is null))
         and m.nro_cuenta = g.nro_cuenta
         and m.cod_transaccion = v_cod_transaccion
         and m.fecha = p_fec_pago
         and m.cod_mad_padre = p_cod_modalidad
       group by g.cod_persona,
                h.nro_cuenta,
                h.cod_moneda,
                h.fecha,
                h.cod_oficina,
                m.hora,
                m.cod_usuario,
                m.nro_secuencia
       --Agregado para evitar mto_retencion = 0--
       having round(((sum(h.mto_interes) * v_por_ret_inr) / 100),
                     fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                     null,
                     null,
                     h.cod_moneda)) > 0;

    --Variables

    rg_dinr         ge_inr_retenciones%rowtype;
    v_mto_retencion ge_inr_retenciones.mto_retencion%type;
    v_cotizacion    ge_cotizaciones.val_conversion%type;
    v_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_error     varchar2(2);
    v_hora          ge_movimientos.hora%type := to_char(sysdate,'HH24:MI:SS');
    
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    rg_actret       ge_inr_retenciones%rowtype;

  begin
    v_nro_secuencia := nvl(p_nro_secuencia, 0);
    v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    v_por_ret_inr   := FUG_OBT_VAL_TASA(v_cod_modulo,
                                        v_cod_modalidad,
                                        null, --Oficina
                                        null, --Nro Cuenta
                                        null, --Cod Moneda
                                        null, --Mto Transaccion
                                        'N',
                                        g_cod_tas_inr, --Cod Tasa
                                        g_cod_tra_inr, --Cod Trx
                                        v_fec_actual);
    For c_dat in c_dat_int_ahorros loop

      If c_dat.mto_interes > 0 then
        rg_dinr.cod_persona   := c_dat.cod_persona;
        rg_dinr.nro_cuenta    := c_dat.nro_cuenta;
        rg_dinr.nro_cupon     := to_number(to_char(trunc(c_dat.fecha),
                                                   'yyyymmdd'));
        rg_dinr.fec_pago      := v_fec_actual;--c_dat.fecha;
        rg_dinr.fec_retencion := v_fec_actual;
        if c_dat.cod_moneda <> v_mon_local then
          v_cotizacion := pag_gen.fu_obt_cotizacion(c_dat.cod_moneda,
                                                    c_dat.fecha);
        else
          v_cotizacion := 1;
        end if;

        rg_dinr.cotizacion  := v_cotizacion;
        rg_dinr.mto_factura := c_dat.mto_interes; ---round(pag_gen.FU_CON_MON_A_MONEDA(c_dat.cod_moneda,v_mon_local,c_dat.mto_interes,v_cotizacion),v_redondeo);
        rg_dinr.cod_moneda  := c_dat.cod_moneda;
        v_redondeo          := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                   null,
                                                   null,
                                                   c_dat.cod_moneda);
        v_mto_retencion := round(((c_dat.mto_interes * v_por_ret_inr) / 100),
                                 v_redondeo);
        rg_dinr.mto_retencion := v_mto_retencion;
        rg_dinr.estado        := 'G';
        rg_dinr.mto_renta     := c_dat.mto_interes;
        rg_dinr.fecha         := c_dat.fecha;
        rg_dinr.hora          := c_dat.hora;
        rg_dinr.cod_usuario   := c_dat.cod_usuario;
        rg_dinr.nro_secuencia := c_dat.nro_secuencia;
        rg_dinr.Nro_Cta_Credito := c_dat.nro_cuenta;
        rg_dinr.por_retencion := v_por_ret_inr;
        pr_ins_ge_inr_retenciones(rg_dinr, v_cod_error);

        If v_cod_error = '00' then
          v_nro_secuencia := v_nro_secuencia + 1;
          v_hora          := fug_obt_hor_disponible(v_fec_actual,
                                                    v_hora,
                                                    user,
                                                    'N');

          -- Actualiza la operacion en la base
          pag_cta.pr_act_operacion(c_dat.nro_cuenta,
                                   v_hora,
                                   'D', -- debito a la cuenta del cliente
                                   c_dat.cod_moneda,
                                   v_mto_retencion,
                                   g_cod_tra_inr, --trx padre
                                   g_cod_tra_inr, --trx hijo
                                   rg_dinr.nro_cupon,
                                   v_cotizacion, -- cotizacion
                                   c_dat.cod_oficina,
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   g_cod_tas_inr, -- tasa
                                   v_por_ret_inr, -- valor de tasa
                                   'Ret.Int.Pag. s/dep. clientes No Residentes', --concepto
                                   'N', -- emitir aviso
                                   p_nro_secuencia, -- nro de secuencia
                                   v_fec_actual);
          if pag_cta.g_cod_error <> 0 then
            --Actualización Dato de Error
            rg_actret.det_error := 'Error al Procesar debito-retencion';
            rg_actret.pro_error := 'PAA_RET.PR_GEN_INR_RET_AHORROS';
            rg_actret.cod_persona := c_dat.cod_persona;
            rg_actret.fec_retencion := c_dat.fecha;
            rg_actret.nro_cuenta := c_dat.nro_cuenta;
            paa_ret.pr_act_ge_inr_retenciones(rg_actret);
          end if;
        else
             --Actualización Dato de Error
            rg_actret.det_error := 'Error al Procesar Retención';
            rg_actret.pro_error := 'PAA_RET.PR_GEN_INR_RET_AHORROS';
            rg_actret.cod_persona := c_dat.cod_persona;
            rg_actret.fec_retencion := c_dat.fecha;
            rg_actret.nro_cuenta := c_dat.nro_cuenta;
            paa_ret.pr_act_ge_inr_retenciones(rg_actret);
        end if;
      end if;

    end loop;

    --Parametro in/out
    p_nro_secuencia := v_nro_secuencia;
    p_mto_retencion := nvl(v_mto_retencion, 0);
    
    --AutoFactura TMP 
    PRB_GEN_LIB_COM_INR_TMP(v_fec_actual);
    
  exception
    when others then
      raise_application_error(-20001,
                              'Error pr_gen_inr_ret_ahorros' || sqlerrm);
  end;

  --Proceso Generación de Retenciones INR CDA
  procedure pr_gen_inr_ret_cda(p_fecha           ge_inr_retenciones.fec_pago%type,
                               p_nro_cuenta      ah_cta_certificados.nro_cuenta%type default null,
                               p_cod_tra_padre   ge_movimientos.cod_tra_padre%type,
                               p_cod_mod_padre   ge_movimientos.cod_mod_padre%type,
                               p_cod_mad_padre   ge_movimientos.cod_mad_padre%type,  
                               p_cod_transaccion ge_movimientos.cod_transaccion%type,
                               p_hora            ge_movimientos.hora%type default null,
                               p_nro_secuencia   in out ge_movimientos.nro_secuencia%type,
                               p_mto_retencion   in out ge_inr_retenciones.mto_retencion%type) is

    v_fec_actual    ge_movimientos.fecha%type := nvl(p_fecha,pag_cal.fu_obt_fec_actual(3));
    v_cod_modulo    ge_movimientos.cod_modulo%type := 3;
    v_cod_modalidad ge_movimientos.cod_modalidad%type := 33;
    v_redondeo      number(5);
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    r_gmovi         ge_movimientos%rowtype;
    v_por_ret_inr   number;
    
    Cursor c_cupon is
      ---Acreditaciones Automaticas
      Select 'N' pro_caja,
             ge.cod_persona,
             cd.nro_cuenta,
             cd.cod_moneda,
             cd.denominacion,
             cu.fec_vencimiento,
             cd.cod_oficina,
             g.monto,
             cu.bloqueado,
             cd.estado est_cuenta,
             cd.cod_modalidad,
             substr(replace(cd.beneficiario, chr(10), ' '), 1, 68),
             cd.est_certificado,
             cu.nro_cupon,
             cu.estado est_cupon,
             g.FECHA,
             g.HORA,
             g.COD_USUARIO,
             g.NRO_SECUENCIA,
             g.nro_documento,
             cd.nro_cta_credito
        from ah_cta_certificados  cd,
             ah_cupones           cu,
             ge_cta_clientes      ge,
             ge_clientes          e,
             ge_movimientos       g,
             ge_sep_transacciones tr
       where cd.nro_cuenta = ge.nro_cuenta
         and cd.cod_modulo = ge.cod_modulo
         and cd.cod_modalidad = ge.cod_modalidad
         and cd.nro_cuenta = cu.nro_cuenta
         and ge.cod_persona = e.cod_persona
         and cd.nro_cuenta = nvl(p_nro_cuenta, cd.nro_cuenta)
         and e.residente = 'N' --para prueba comentar el residente, estado cupon y cupon bloqueado
         and cd.estado not in ('A', 'T', 'C')
         and cu.estado = 'P'
         and ge.relacion = 'P'
         and nvl(g.monto, 0) > 0
         and nvl(cu.bloqueado, 'N') = 'N'
         and cd.cre_automatico = 'S'
         and cd.nro_cta_credito is not null
         and cu.fec_vencimiento <= v_fec_actual
         and cu.nro_cupon = g.nro_documento
         and tr.ref_archivo = 'INR_CDA'
         and tr.ref_dat_reportar = 'INR_CDA_CREDITO'
         and g.cod_tra_padre = tr.cod_tra_padre
         and g.cod_transaccion = tr.cod_transaccion
         and g.cod_mod_padre = tr.cod_mod_padre
         and g.cod_modulo = tr.cod_modulo
         and g.cod_mad_padre = tr.cod_mad_padre
         and g.cod_modalidad = tr.cod_modalidad
         and cd.nro_cuenta = g.nro_cuenta
         and g.fecha = nvl(p_fecha,g.fecha)
         and g.cod_transaccion = nvl(p_cod_transaccion, g.cod_transaccion)
         and g.cod_tra_padre = nvl(p_cod_tra_padre, g.cod_tra_padre)
         and g.hora = nvl(p_hora, g.hora)
         and not exists (select 1
                           from ge_inr_retenciones r
                          where r.nro_cuenta = cd.nro_cuenta
                            and r.nro_cupon = cu.nro_cupon)
         ----Agregado para evitar mto_retencion = 0--
         and round(((g.monto * v_por_ret_inr) / 100),
                               fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                               null, null, cd.cod_moneda)) > 0
         ----
      union all
      ---Pago por Caja / a Requerimiento
      Select 'S' pro_caja,
             ge.cod_persona,
             cd.nro_cuenta,
             cd.cod_moneda,
             cd.denominacion,
             cd.fec_vencimiento,
             cd.cod_oficina,
             v.MONTO,
             cu.bloqueado,
             cd.estado est_cuenta,
             cd.cod_modalidad,
             substr(replace(cd.beneficiario, chr(10), ' '), 1, 68),
             cd.est_certificado,
             cu.nro_cupon,
             cu.estado est_cupon,
             v.FECHA,
             v.HORA,
             v.COD_USUARIO,
             v.NRO_SECUENCIA,
             v.nro_documento,
             v.nro_cuenta nro_cta_credito
        from ah_cta_certificados  cd,
             ah_cupones           cu,
             ge_cta_clientes      ge,
             ge_clientes          e,
             ge_movimientos       v,
             ge_sep_transacciones tr
       where cd.nro_cuenta = ge.nro_cuenta
         and cd.cod_modulo = ge.cod_modulo
         and cd.cod_modalidad = ge.cod_modalidad
         and cd.nro_cuenta = cu.nro_cuenta
         and ge.cod_persona = e.cod_persona
         and e.residente = 'N' --para prueba comentar el residente, estado cupon y cupon bloqueado
         and cu.estado = 'P'
         and nvl(cu.bloqueado, 'N') = 'N'
         and ge.relacion = 'P'
         and cd.nro_cuenta = v.nro_cuenta
         and cu.nro_cupon = v.nro_documento
         and cd.nro_cuenta = nvl(cd.nro_cuenta, p_nro_cuenta)
         and v.fecha = p_fecha
         and nvl(v.monto, 0) > 0
         and v.hora = nvl(p_hora, v.hora)
         and tr.ref_archivo = 'INR_CDA'
         and tr.ref_dat_reportar = 'INR_CDA_CAJA'
         and v.cod_tra_padre = tr.cod_tra_padre
         and v.cod_transaccion = tr.cod_transaccion
         and v.cod_mod_padre = tr.cod_mod_padre
         and v.cod_modulo = tr.cod_modulo
         and v.cod_mad_padre = tr.cod_mad_padre
         and v.cod_modalidad = tr.cod_modalidad
         and cu.fec_vencimiento <= V_FEC_ACTUAL
         and not exists (select 1
                           from ge_inr_retenciones r
                          where r.nro_cuenta = cd.nro_cuenta
                            and r.nro_cupon = cu.nro_cupon)
         ----Agregado para evitar mto_retencion = 0--
         and round(((v.monto * v_por_ret_inr) / 100),
                               fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                               null, null, cd.cod_moneda)) > 0; 

    --Variables
    rg_dinr         ge_inr_retenciones%rowtype;
    v_mto_retencion ge_inr_retenciones.mto_retencion%type;
    v_mto_equ_local ge_movimientos.mto_equ_local%type;
    v_cotizacion    ge_cotizaciones.val_conversion%type;
    v_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_error     varchar2(2);
    v_hora          ge_movimientos.hora%type := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));    
    rg_actret       ge_inr_retenciones%rowtype;

  begin
    
    v_por_ret_inr := FUG_OBT_VAL_TASA(v_cod_modulo,
                                      v_cod_modalidad,
                                      null, --Oficina
                                      null, --Nro Cuenta
                                      null, --Cod Moneda
                                      null, --Mto Transaccion
                                      'N',
                                      g_cod_tas_inr,
                                      g_cod_tra_inr,
                                      v_fec_actual);

    v_nro_secuencia := nvl(p_nro_secuencia, 0);
    v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
    For c_dat in c_cupon loop
        
      If c_dat.monto > 0 then
        rg_dinr.cod_persona   := c_dat.cod_persona;
        rg_dinr.nro_cuenta    := c_dat.nro_cuenta;
        rg_dinr.nro_cupon     := c_dat.nro_cupon;
        rg_dinr.fec_pago      := v_fec_actual;--c_dat.fec_vencimiento;
        rg_dinr.fec_retencion := v_fec_actual;
        rg_dinr.mto_factura   := c_dat.monto;
        rg_dinr.cod_moneda    := c_dat.cod_moneda;
        v_redondeo            := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                     null,
                                                     null,
                                                     c_dat.cod_moneda);

        v_mto_retencion := round(((c_dat.monto * v_por_ret_inr) / 100),
                                 v_redondeo);
        if c_dat.cod_moneda <> v_mon_local then
          v_cotizacion    := pag_gen.fu_obt_cotizacion(c_dat.cod_moneda,
                                                       v_fec_actual);
          v_mto_equ_local := round(v_mto_retencion * v_cotizacion,
                                   fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                       null,
                                                       null,
                                                       pag_gen.FU_OBT_MON_LOCAL,
                                                       null));
        else
          v_cotizacion := 1;
        end if;
        rg_dinr.cotizacion    := v_cotizacion;
        rg_dinr.mto_retencion := v_mto_retencion;
        rg_dinr.estado        := 'G';
        rg_dinr.mto_renta     := c_dat.monto;
        rg_dinr.fecha         := c_dat.fecha;
        rg_dinr.hora          := c_dat.hora;
        rg_dinr.cod_usuario   := c_dat.cod_usuario;
        rg_dinr.nro_secuencia := c_dat.nro_secuencia;
        rg_dinr.por_retencion := v_por_ret_inr;
        if c_dat.pro_caja = 'N' then
           if nvl(pae_cnf.G_PROGRAMA,'x') <> 'GPPROFIN' then
            --Los cobros por caja e it debe generar en misma cta cda
             rg_dinr.nro_cta_credito := c_dat.nro_cuenta;
           else
             --Solo los créditos automáticos debe generar mov en cta distinta
             rg_dinr.nro_cta_credito := c_dat.nro_cta_credito;
           end if;
        else
           --Los cobros por caja e it debe generar en misma cta cda
           rg_dinr.nro_cta_credito := c_dat.nro_cuenta;
        end if;
        
        pr_ins_ge_inr_retenciones(rg_dinr, v_cod_error);
  
        if v_cod_error = '00' then
          if c_dat.pro_caja = 'N' and nvl(pae_cnf.G_PROGRAMA,'x') <> 'AMPAGCUP' then
            pag_cta.PR_OBT_CUENTA(c_dat.nro_cta_credito);
              if v_nro_secuencia > 990 then
                 v_nro_secuencia := 0;
                 v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
              else
                 v_hora := v_hora;
                 v_nro_secuencia := v_nro_secuencia + 1;
              end if;
            
            
            -- Actualiza la operacion en la base
            pag_cta.pr_act_operacion(c_dat.nro_cta_credito,
                                     v_hora,
                                     'D', -- debito a la cuenta del cliente
                                     c_dat.cod_moneda,
                                     v_mto_retencion,
                                     p_cod_tra_padre, --trx padre
                                     g_cod_tra_inr, --trx hijo
                                     c_dat.nro_cupon, --nro doc para movimiento
                                     v_cotizacion, -- cotizacion
                                     c_dat.cod_oficina,
                                     v_cod_modulo, --modulo padre
                                     v_cod_modalidad, --modalidad padre
                                     g_cod_tas_inr, -- codigo tasa
                                     v_por_ret_inr, -- valor de tasa
                                     'Ret.Int.Pag. s/dep. clientes No Residentes Cta.: '||c_dat.nro_cuenta, --concepto
                                     'N', -- emitir aviso
                                     v_nro_secuencia, -- nro de secuencia
                                     v_fec_actual,
                                     null,
                                     null,
                                     v_mto_equ_local,
                                     null);

            if pag_cta.g_cod_error <> 0 then
              ---Actualización Dato de Error
              rg_actret.det_error      := pag_cta.g_msj_error||'-'||sqlerrm;
              rg_actret.pro_error      := 'PAA_RET.PR_GEN_INR_RET_CDA';
              rg_actret.cod_persona    := c_dat.cod_persona;
              rg_actret.fec_retencion  := c_dat.fecha;
              rg_actret.nro_cuenta     := c_dat.nro_cuenta;
              paa_ret.pr_act_ge_inr_retenciones(rg_actret);
           
            end if;
          else --- Si pago es por Caja o Pago Manual por ITGF
              if v_nro_secuencia > 990 then
                 v_nro_secuencia := 0;
                 v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
              else
                 v_hora := v_hora;
                 v_nro_secuencia := v_nro_secuencia + 1;
              end if;
              r_gmovi.cod_usuario       := user;
              r_gmovi.hora              := v_hora;
              r_gmovi.nro_secuencia     := v_nro_secuencia;
              r_gmovi.cod_mod_padre     := p_cod_mod_padre;
              r_gmovi.cod_mad_padre     := p_cod_mad_padre;
              r_gmovi.cod_modulo        := v_cod_modulo;
              r_gmovi.cod_modalidad     := v_cod_modalidad;
              r_gmovi.cod_oficina       := c_dat.cod_oficina;
              r_gmovi.nro_cuenta        := c_dat.nro_cuenta;
              r_gmovi.cod_moneda        := c_dat.cod_moneda;
              r_gmovi.monto             := v_mto_retencion;
              r_gmovi.cod_tra_padre     := p_cod_tra_padre;
              r_gmovi.cod_transaccion   := g_cod_tra_inr;
              r_gmovi.est_cuenta        := c_dat.est_cuenta;
              r_gmovi.estado            := 'N';
              r_gmovi.reversado         := 'N';
              r_gmovi.emi_aviso         := 'N';
              r_gmovi.protegido         := 'N';
              r_gmovi.nro_documento     := c_dat.nro_cupon;
              r_gmovi.cod_ofi_origen    := c_dat.cod_oficina;
              r_gmovi.fecha             := v_fec_actual;
              r_gmovi.fec_valor         := v_fec_actual;
              r_gmovi.cod_tasa          := g_cod_tas_inr; -- codigo tasa
              r_gmovi.val_tasa          := v_por_ret_inr; -- valor de tasa
              pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
              
          end if;         
      
         else
            ---Actualización Dato de Error
            rg_actret.det_error := 'Error al Procesar Retención';
            rg_actret.pro_error := 'PAA_RET.PR_GEN_INR_RET_CDA';
            rg_actret.cod_persona := c_dat.cod_persona;
            rg_actret.fec_retencion := c_dat.fecha;
            rg_actret.nro_cuenta := c_dat.nro_cuenta;
            paa_ret.pr_act_ge_inr_retenciones(rg_actret);
        end if;
      end if;
      
      --Limpiar variables globales datos de cuenta
      pag_cta.PR_OBT_CUENTA(null);
    end loop;

    --AutoFactura TMP 
    PRB_GEN_LIB_COM_INR_TMP(v_fec_actual);
    
    --Parametro in/out
    p_nro_secuencia := v_nro_secuencia;
    p_mto_retencion := nvl(v_mto_retencion, 0);

  exception
    when others then
      raise_application_error(-20001,
                              'Error pr_gen_inr_ret_ahorros' || sqlerrm);
  end;

  ----
  procedure pr_act_ge_inr_retenciones(pg_actret     ge_inr_retenciones%rowtype) is

    --Variables
    rg_actret            ge_inr_retenciones%rowtype := pg_actret;
    v_des_mail           varchar2(120) := fug_obt_pardinamico('DIR_MAIL_ARC_RETENCIONES');
    v_rem_mail           varchar2(120) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'); --'bbvanet@bbva.com.py';
    v_conn               utl_smtp.connection;

  begin
   
  update ge_inr_retenciones r
     set r.nro_factura      = rg_actret.nro_factura,
         r.mto_factura      = rg_actret.mto_factura,
         r.fec_vig_timbrado = rg_actret.fec_vig_timbrado,
         r.nro_timbrado     = rg_actret.nro_timbrado,
         r.pro_error        = rg_actret.pro_error,
         r.det_error        = rg_actret.det_error
   where r.cod_persona      = rg_actret.cod_persona
     and r.nro_cuenta       = rg_actret.nro_cuenta
     and r.cod_retencion    = rg_actret.cod_retencion;

  exception
    when others then
       v_conn := it_mail.begin_mail(v_des_mail,
                                    v_rem_mail,
                                    'Error al Actualizar Ret. Cliente: '||rg_actret.cod_persona
                                     ||'Cta.: '||rg_actret.nro_cuenta
                                     ||'Proc.:'|| rg_actret.pro_error);
   end;

  ----

procedure pr_gen_notificaciones is
  v_des_mail     varchar2(120) := fug_obt_pardinamico('DIR_MAIL_ARC_RETENCIONES');
  v_rem_mail     varchar2(120) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
  v_conn         utl_smtp.connection;
  v_fec_anterior ge_calendarios.fec_anterior%type := fug_obt_fec_anterior(1);
  v_det_mail     tm_mails.detalles%type;          
  v_can_error    number;   
  v_error_mail   varchar2(4000);
  v_hora_log     varchar2(20) := to_char(sysdate,'hh24:mi:ss');
  
  Cursor c_errores is 
    Select cod_persona, nro_cuenta, fec_retencion, pro_error, det_error
      from ge_inr_retenciones r
     where r.det_error is not null
       and r.fec_retencion = v_fec_anterior
     union
    Select cod_persona, nro_cuenta, fec_retencion, 
           'Verificación Datos' pro_error, 
           'Retención Generada sin Factura-Verificar' det_error
      from ge_inr_retenciones r
     where r.nro_factura is null
     and r.fec_retencion = v_fec_anterior;


  begin
     v_can_error := 0;
     For c_err in c_errores loop
         
         If v_can_error = 0 then
            v_det_mail := 'Cliente: '||c_err.cod_persona||
                          ' , Cta.: '|| c_err.nro_cuenta||
                          ' , Proc.: '|| c_err.pro_error||'-'||
                          c_err.det_error||chr(10);
         Else
            v_det_mail := substr(v_det_mail||chr(10)||'Cliente: '||c_err.cod_persona||
                          ' , Cta.: '|| c_err.nro_cuenta||
                          ' , Proc.: '|| c_err.pro_error||'-'||
                          c_err.det_error||chr(10),1,3800);
         End if;
         
         v_can_error := v_can_error + 1;
         
     End loop;
    
     if v_can_error > 0 then
          begin
            --DE, PARA y el ASUNTO
             v_conn := it_mail.begin_mail(v_rem_mail,
                                          v_des_mail,
                                          'Errores en Procesos de INR: '||v_fec_anterior);
            --Cuerpo del mail
             it_mail.write_text(v_conn,substr('Se han encontrado '|| v_can_error||' errores: '||chr(10)||
                                        v_det_mail||
                                        chr(10)||'Para mas detalles ver Consulta Dinámica.',1,4000));
             it_mail.end_mail(v_conn);
             
           exception
            when others then
              v_error_mail := sqlerrm;
              insert into ge_log_mail
                (fec_envio,
                 cod_persona,
                 dir_correo,
                 mensaje,
                 det_error,
                 nro_cuenta,
                 hor_inicio,
                 hor_fin)
              values
                (trunc(sysdate),
                 null,
                 v_rem_mail,
                 'Error en envío de mail Procesos INR '||v_fec_anterior,
                 v_error_mail,
                 null,
                 v_hora_log,
                 v_hora_log);
          end;     
  
     end if;   
  
  end;

---Función para obtener monto retencion CDA 
function fu_obt_inr_ret_cda(p_nro_cuenta      ah_cta_certificados.nro_cuenta%type,
                            p_cod_modalidad   ah_cta_certificados.cod_modalidad%type,
                            p_serie           ah_cta_certificados.serie%type,
                            p_nro_certificado ah_cta_certificados.nro_certificado%type,
                            p_cod_moneda      ah_cta_certificados.cod_moneda%type,
                            p_nro_cupon       ah_cupones.nro_cupon%type,
                            p_fecha           ge_movimientos.fecha%type) return number is
 
    v_fec_actual    ge_movimientos.fecha%type := nvl(p_fecha,pag_cal.fu_obt_fec_actual(3));
    v_cod_modulo    ge_movimientos.cod_modulo%type := 3;
    v_cod_modalidad ge_movimientos.cod_modalidad%type := p_cod_modalidad;
    v_redondeo      number(5);
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    v_por_ret_inr   number;
    v_mto_retencion ge_inr_retenciones.mto_retencion%type;
    v_mto_equ_local ge_movimientos.mto_equ_local%type;
    v_cotizacion    ge_cotizaciones.val_conversion%type;
    v_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
    v_cod_moneda    ah_cta_certificados.cod_moneda%type;
    v_mto_interes   ah_cupones.mto_interes%type;

  begin
   begin

      Select cd.cod_moneda,
             cu.mto_interes
        into v_cod_moneda,
             v_mto_interes
        from ah_cta_certificados  cd,
             ah_cupones           cu,
             ge_cta_clientes      ge,
             ge_clientes          e
       where cd.nro_cuenta = ge.nro_cuenta
         and cd.cod_modulo = ge.cod_modulo
         and cd.cod_modalidad = ge.cod_modalidad
         and cd.nro_cuenta = cu.nro_cuenta
         and ge.cod_persona = e.cod_persona
         and e.residente = 'N' --para prueba comentar el residente, estado cupon y cupon bloqueado
         and cd.estado not in ('A', 'T', 'C')
         and cu.estado = 'V'
         and ge.relacion = 'P'
         and cu.fec_vencimiento <= v_fec_actual
         and cd.nro_cuenta =  p_nro_cuenta
         and cd.cod_modalidad = v_cod_modalidad
         and cd.serie = p_serie
         and cd.cod_moneda = p_cod_moneda
         and cu.nro_cupon =  p_nro_cupon
         and cd.nro_certificado =  to_number(p_nro_certificado)
            --  and cd.nro_cuenta is null
         and not exists (select 1
                          from ge_inr_retenciones r
                         where r.nro_cuenta = cd.nro_cuenta
                           and r.nro_cupon = cu.nro_cupon);

   exception
     when no_data_found then
        v_mto_interes := 0;
     when others then
       v_mto_interes := 0;
   end;
   
   If v_mto_interes > 0 then
      v_por_ret_inr := FUG_OBT_VAL_TASA(v_cod_modulo,
                                        v_cod_modalidad,
                                        null, --Oficina
                                        null, --Nro Cuenta
                                        null, --Cod Moneda
                                        null, --Mto Transaccion
                                        'N',
                                        g_cod_tas_inr,
                                        g_cod_tra_inr,
                                        v_fec_actual);

       v_redondeo            := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                       null,
                                                       null,
                                                       v_cod_moneda);

       v_mto_retencion := round(((v_mto_interes * v_por_ret_inr) / 100),
                                 v_redondeo);

    End if;

    return nvl(v_mto_retencion, 0);

exception
  when others then
     return nvl(v_mto_retencion, 0);
end;

end paa_ret;
/

