CREATE OR REPLACE PROCEDURE IT.PRP_PRO_SEG_CUOTAS IS

v_fec_actual      date := pae_cnf.fu_obt_fec_actual(6);
v_nro_solicitud   pr_solicitudes.nro_solicitud%type;
v_fec_ven_cuota   pr_cuotas.fec_vencimiento%type;
-- Cursor de solicitudes desembolsadas en la fecha
Cursor c_solicitudes is
 select * from pr_solicitudes s
  where s.estado = 'A'
    and s.fec_aprobacion = v_fec_actual
    and 0 <> (select count(*) from pr_sol_cargos car
               where car.nro_solicitud = s.nro_solicitud
                 and car.cod_ent_seguro is not null
                 and car.cod_transaccion = 1520); -- incendio
-- Cursor de seguros
Cursor c_seguros is
 select car.cod_ent_seguro, car.cod_transaccion, car.cod_moneda, car.val_Tasa,
        sum(car.monto) monto, sum(car.mto_mon_prestamo) montousd
 from pr_sol_cargos car
 where car.nro_solicitud = v_nro_solicitud
   and cod_ent_seguro is not null
   and cod_transaccion = 1520  -- incendio
 Group by car.cod_ent_seguro, car.cod_transaccion, car.cod_moneda, car.val_tasa;

-- RI: 11/06/2010 : Cursor de solicitudes de cuotizacion de prestamos en etapas,
-- a fin de sumar la totalidad de cuotas adeudadas por el cliente por Seguro
-- de Incendio y fraccionar dicho total en tantas cuotas mensuales como meses falten para
-- cumplirse 12 meses a partir del último desembolso.
Cursor c_sol_seg is
 select s.* from pr_cta_prestamos c, pr_solicitudes s
  where s.estado = 'A'
    and s.fec_aprobacion = v_fec_actual
    and s.tip_renovacion = 'D'
    and c.nro_solicitud = s.nro_solicitud
    and exists (select 0
                  from pr_cuotas cu
                 where cu.nro_cuenta = c.nro_cuenta
                   and cu.mto_capital > 0
                   and cu.nro_cuota > 0
                 having count(*) > 1)
    and 0 = (select count(*) from pr_sol_cargos car
               where car.nro_solicitud = s.nro_solicitud
                 and car.cod_transaccion = 1520); -- incendio

-- Cursor de los cobros de cargos por seguro en cuotas de la fecha
Cursor c_cobros is
Select t.fecha, t.hora, t.nro_cuenta, t.cod_Transaccion, t.cod_moneda,
       c.cod_ent_seguro, t.monto, t.nro_secuencia, t.cod_usuario
       ,t.nro_documento, t.nro_documento2, t.nro_documento3, t.cod_modulo,
       t.cod_modalidad, t.cod_oficina
  from Ge_sol_Cargos c, ge_movimientos t
 where t.cod_tra_padre in (360,362,359,364)  -- cobros de cuotas, cancelacion anticip. parcial, cancelacion total, debito automatico prestamos
   and t.estado = 'N'
   and t.reversado = 'N'
   and exists (select tr.cod_transaccion from ge_transacciones tr
                where tr.cod_modulo = t.cod_modulo
                  and tr.cod_modalidad = t.cod_modalidad
                  and tr.cod_transaccion = t.cod_Transaccion
                  and tr.afecta = 'G')   -- G= Afecta Seguro en cuotas
   and c.cod_modulo    = t.cod_modulo
   and c.cod_modalidad = t.cod_modalidad
   and c.cod_transaccion = t.cod_transaccion
   -----------------------------------------------------------
   --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)----
   --Exclusion ctas c/seg. distr. son contabil. en ganancias--
   -----------------------------------------------------------
   and ((t.cod_Transaccion = 1521 and (not exists (select 1
                     from ba_tab_dat_adicionales x, pr_solicitudes y, pr_cta_prestamos z
                    where z.nro_cuenta = t.nro_cuenta
                      and y.nro_solicitud = z.nro_solicitud
                      and x.tab_relacion = 'PR_SOLICITUDES'
                      and x.parametro = 'PRE_IND_CUO_CAL_SEGURO'
                      and x.referencia = y.nro_solicitud
                      and x.val_parametro = 'S')))
        or (t.cod_Transaccion <> 1521))
-- TN-1215: Se excluye la modalidad CHE ROGA para evitar duplicacion en la facturación
    and not exists (
      select 1
      from ge_par_dinamicos
      where parametro = 'EXC_MAD_CUO_SEGURO'
      and cod_modulo = t.cod_modulo
      and cod_modalidad = t.cod_modalidad    
   )
 order by nro_cuenta, cod_transaccion, fecha, hora; --BBVASOP-1022. CB.
--
v_importe         ge_movimientos.monto%type;
v_cuenta          pr_cta_prestamos.nro_cuenta%type;
v_nro_comprobante ge_movimientos.nro_documento3%type;
v_can_cuotas      pr_cta_prestamos.can_cuotas%type;
v_imp_cuota       pr_sol_cargos.monto%type;
v_tot_cargo       pr_sol_cargos.monto%type;
v_cargo_iva       pr_sol_cargos.monto%type;
v_imp_restante    pr_sol_cargos.monto%type;
v_cod_tra_movimiento ge_movimientos.cod_transaccion%type;
v_fec_primer_vto  pr_cuotas.fec_vencimiento%type;
v_fec_vto         pr_cuotas.fec_vencimiento%type;
v_fec_vigencia    pr_cuotas.fec_vencimiento%type;
v_fec_ult_desemb  pr_cuotas.fec_vencimiento%type;
v_redondeo_ml     number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
v_redondeo        number;
v_nro_secuencia   ge_movimientos.nro_secuencia%type := 0;
v_hora            ge_movimientos.hora%type;
v_cod_usuario     ge_movimientos.cod_usuario%type := user;
v_cod_mon_local   ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
v_cotizacion      ge_movimientos.cotizacion%type;
v_cta_cre         ge_movimientos.nro_cuenta%type;
v_cod_tasa        ge_movimientos.cod_tasa%type;
v_cod_tas_seg_vida ge_movimientos.cod_tasa%type;
v_tas_prima       ge_movimientos.cod_tasa%type;
v_tas_incendio    ge_movimientos.cod_tasa%type;
v_val_Tasa        ge_movimientos.val_tasa%type;
v_val_tas_prima   ge_movimientos.val_tasa%type;
v_val_tas_incendio ge_movimientos.val_tasa%type;
v_val_tas_seg_vida ge_movimientos.val_tasa%type;
v_tip_Valor       ge_Tasas.Tip_Valor%type;
v_tipo            ge_Tasas.Tipo%type;
v_cod_ofi_origen  ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
v_tra_padre       ge_transacciones.cod_transaccion%type;
v_cod_transaccion ge_transacciones.cod_transaccion%type;
v_cod_persona     ba_personas.cod_persona%type;
v_cod_gar_hipotecaria  number;
v_val_edilicio         pr_gar_hipotecarias.val_edilicio%type := 0;
v_val_edilicio_mon     pr_gar_hipotecarias.val_edilicio%type := 0;
v_tot_val_edilicio     pr_gar_hipotecarias.val_edilicio%type := 0;
v_mto_capital     number;
v_cot1            number;
v_cot2            number;
-- Variables de registro
r_pcpre           pr_cta_prestamos%rowtype;
r_gmovi           ge_movimientos%rowtype;
--
v_fec_vto_ant     date;
v_cod_rubro       cb_rubros.cod_rubro%type;
v_cod_mon_rubro   cb_rubros.cod_moneda%type;
v_nro_cta_aux     ge_movimientos.nro_cuenta%type;
v_fec_vencimiento pr_cta_prestamos.fec_vencimiento%type;
v_fec_inicio      pr_cta_prestamos.fec_inicio%type;
v_cod_ent_seguro  pr_sol_cargos.cod_ent_seguro%type;
--------------------------------------------------------------------------------------------
function Fu_redondear_centena(p_importe in number)  return number is
v_imp number;
v_imp_cen number;

begin
  if  p_importe/100 = trunc(p_importe/100) then  -- esta bien
    v_imp_cen := p_importe;
  else
    v_imp := round(p_importe / 100);
    v_imp_cen := v_imp * 100;
    loop
      if v_imp_cen >= p_importe then
        exit;
      end if;
      v_imp_cen := v_imp_Cen + 100;
    end loop;
  End if;
  return v_imp_Cen;
END;

--------------------------------------------------------------------------------------------
--  EMPIEZA EL PROCEDIMIENTO
--------------------------------------------------------------------------------------------
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_hora := to_char(sysdate,'hh24:mi:ss');
  v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');


  For sol in c_solicitudes loop
    v_nro_solicitud  := sol.nro_solicitud;
    --Obtener nro. cuenta del prestamo
    Begin
      Select nro_cuenta
        into v_cuenta
        from pr_sol_tasas t, pr_cta_prestamos s
       where s.nro_solicitud = v_nro_solicitud
         and t.nro_solicitud = s.nro_solicitud;
    Exception
      When others then
       raise_application_error(-20000, 'Error al traer datos del prestamo. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
    End;
    --Traer los datos del prestamo
    pap_pre.pr_obt_dat_prestamo(v_cuenta, r_pcpre);
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
    v_tot_cargo := 0;
    v_can_cuotas := 0;
    For seg in c_seguros loop
-------------------------------------------------------------------------------------------------
--1  ESTA PARTE ES PARA GENERAR LOS CARGOS POR SEGUROS EN CUOTAS - INCENDIO
-------------------------------------------------------------------------------------------------

       --Verificar si es un desembolso en etapas, si es asi debe generar la cantidad de cuotas
       -- que quedaron pendientes
       if sol.nro_sol_original is not null then
          select count(distinct c.fec_ini_vigencia)
            into v_can_cuotas
            from Pr_cta_gastos c, pr_cta_prestamos p
           where p.nro_cta_renovada = v_cuenta
             and c.nro_cuenta = p.nro_cuenta
             and c.cod_transaccion = 1520
             and c.fec_ini_vigencia > v_fec_actual;
       End if;
       If nvl(v_can_cuotas,0) = 0 then
          v_can_cuotas := nvl(fug_obt_pardinamico('CAN_CUO_SEG_INCENDIO'),12);  --ver si se puede parametrizar
       end if;
       v_imp_cuota  := trunc(seg.monto / v_can_cuotas,v_redondeo);
       --
       -- Traer la fecha de vencimiento de la cuota 0
       Begin
         Select fec_vencimiento
           into v_fec_primer_vto
            from pr_cuotas
           where nro_cuenta = v_cuenta
             and nro_cuota  = 0;
         Exception
           when others then
             raise_application_error(-20000, 'Error en Generar Mov. Seguro al traer fecha de vencimiento de cuota. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
        End;
        --
        v_fec_vto_ant := v_fec_primer_vto;
        FOR i IN 1..v_can_cuotas LOOP
           select min(fec_vencimiento)
             into v_fec_vto
             from pr_cuotas
            where nro_cuenta = v_cuenta
              and fec_vencimiento  > v_fec_vto_ant;
           if v_fec_vto is null then
              v_fec_vto := Add_months(v_fec_vto_ant,1);
           end if;
           --
           Insert into Pr_cta_gastos
           (Nro_cuenta, Cod_transaccion, cod_moneda, Monto, Fec_ingreso,
            Fec_ini_vigencia, Fec_vencimiento, Cod_modalidad, cod_modulo,nro_solicitud)
           Values
           (r_pcpre.nro_cuenta, seg.cod_transaccion, seg.cod_moneda, v_imp_cuota, v_fec_vto,
            v_fec_vto, null, r_pcpre.cod_modalidad, r_pcpre.cod_modulo,r_pcpre.nro_solicitud);
           --
           v_tot_cargo := nvl(v_tot_cargo,0) + nvl(v_imp_cuota,0);
           v_fec_vto_ant := v_fec_vto;
        END LOOP;
        -- Ver si hay que ajustar alguna diferencia
        if  v_tot_cargo < seg.monto then
           Update pr_cta_gastos
              set monto = nvl(monto,0)+ (seg.monto-v_tot_Cargo)
            where nro_cuenta = r_pcpre.nro_cuenta
              and fec_ini_vigencia = v_fec_vto;  -- la ultima
        elsif v_tot_Cargo > seg.monto then
           Update pr_cta_gastos
              set monto = nvl(monto,0)- (v_tot_cargo-seg.monto)
            where nro_cuenta = r_pcpre.nro_cuenta
              and fec_ini_vigencia = v_fec_vto;  -- la ultima
        end if;
-------------------------------------------------------------------------------------------------
--  ESTA PARTE ES PARA GENERAR LOS MOVIMIENTOS QUE CORRESPONDEN POR LOS CARGOS Y EL CREDITO EN LA
--  CUENTA DE LA PROCESADORA
-------------------------------------------------------------------------------------------------
      /*
      -- Generar el movimiento por el total del cargo por seguro
      */
      v_nro_secuencia := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia      := v_nro_secuencia;
      r_gmovi.cod_usuario        := v_cod_usuario;
      r_gmovi.hora               := v_hora;
      r_gmovi.fecha              := v_fec_actual;
      r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
      r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
      r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
      r_gmovi.nro_cuenta         := null;
      r_gmovi.cod_moneda         := seg.cod_moneda;
      r_gmovi.est_cuenta         := null;
      r_gmovi.cod_tra_padre      := 365;  -- Cargos por seguro en cuotas
      r_gmovi.cod_transaccion    := 1523;  -- Debito por cargo de seguros a cuenta en suspenso
      r_gmovi.concepto           := 'Cargos por Seguro de Incendio';
      r_gmovi.monto              := seg.monto;
      if seg.cod_moneda <> v_cod_mon_local then
         v_cotizacion               := pag_gen.fu_obt_cotizacion(seg.cod_moneda, v_fec_actual);
         r_gmovi.cotizacion         := v_cotizacion;
         r_gmovi.mto_equ_local      := round(trunc(seg.monto,2)*v_cotizacion,v_redondeo_ml);
      else
         v_cotizacion               := null;
         r_gmovi.cotizacion         := null;
         r_gmovi.mto_equ_local      := null;
      end if;
      r_gmovi.fec_valor          := v_fec_actual;
      r_gmovi.emi_aviso          := 'N';
      r_gmovi.reversado          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
      r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
      r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
      r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01/09/10
      r_gmovi.val_tasa           := seg.val_tasa;
      r_gmovi.cod_persona        := sol.cod_persona;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
     /*
     -- Esta parte corresponde al credito del monto a pagar a la Aseguradora
     -- en su cuenta
     --*/
     begin
         v_cta_cre := null;
         if fug_obt_tip_ente(seg.cod_ent_seguro) = 'SE' then
            if seg.cod_moneda = v_cod_mon_local then
               v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_SEG_MON_LOCAL');
               v_cod_rubro := fug_obt_parentes(seg.cod_ent_seguro, 'COD_RUB_MON_LOCAL');
            else
               v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_SEG_MON_FUERTE');
               v_cod_rubro := fug_obt_parentes(seg.cod_ent_seguro, 'COD_RUB_MON_FUERTE');
            end if;
         else
            v_cta_cre := fug_obt_parentes(seg.cod_ent_seguro, 'NRO_CTA_ESCRIBANIA');
         end if;
      exception
           when others then v_cta_cre := null;
      end;
      ---
      v_cod_gar_hipotecaria := fug_obt_pardinamico('COD_GAR_HIP_VIVIENDA',r_pcpre.cod_modulo,null,null,null);
      --Total Tasación de la Garantias Hipotecarias
       v_val_edilicio     := 0;
       v_val_edilicio_mon := 0;
       v_tot_val_edilicio := 0;
       for k in (select x.*
                   from pr_cta_garantias x
                  where x.nro_cuenta = r_pcpre.nro_cuenta
                    and x.cod_garantia = v_cod_gar_hipotecaria) loop

         Declare
           Cursor c_cur is
           select cod_mon_tasacion, sum(val_edilicio) val_edilicio
             from pr_garantias g, pr_gar_hipotecarias h
            where h.nro_garantia = k.nro_garantia
              and g.nro_garantia = h.nro_garantia
            group by cod_mon_tasacion;
         Begin
           For c1 in c_cur loop
             v_val_edilicio     := c1.val_edilicio;
               v_val_edilicio_mon := c1.val_edilicio;
                   If c1.cod_mon_tasacion <> r_pcpre.cod_moneda then
                                    v_cot1 := null;
                                    v_cot2 := null;
                pag_gen.pr_con_mon_a_moneda(c1.cod_mon_tasacion, r_pcpre.cod_moneda,
                                            v_val_edilicio, v_val_edilicio_mon,
                                            v_cot1,v_cot2);
                                    v_val_edilicio := v_val_edilicio_mon;
                   end if;
           End loop;
         End;
         v_tot_val_edilicio := nvl(v_tot_val_edilicio,0) + nvl(v_val_edilicio,0);
       end loop;

      --Traer valor de la tasa de prima seguro vida.
      v_tas_prima := fug_obt_parentes(seg.cod_ent_seguro, 'COD_TAS_PRI_ASE_INCENDIO');
      if  v_tas_prima is not null then
        PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,r_pcpre.cod_modalidad,r_pcpre.cod_oficina,
                 r_pcpre.nro_cuenta,  r_pcpre.cod_moneda, (r_pcpre.fec_vencimiento-r_pcpre.fec_inicio),
                 'N', v_tas_prima,  NULL, r_pcpre.fec_inicio, v_val_tas_prima,v_fec_vigencia,
                 v_tip_valor, v_tipo);
        if v_val_tas_prima is null then
          raise_application_error(-20000,'No encuentra valor de la tasa del seguro de Incendio. Verifique');
        end if;
      else
         raise_application_error(-20000,'No encuentra código de la tasa prima seguro Incendio. Verifique');
      end if;
      --Si en los Parámetros del Ente esta configurado un Rubro Contable se realiza el Crédito a este Rubro
      if v_cod_rubro is not null then
         v_cod_mon_rubro := pag_sue.fu_obt_mon_rubro(v_cod_rubro);
         if v_cod_mon_rubro != v_cod_mon_local then
            v_tot_cargo := seg.montousd;
         else
            v_tot_cargo := seg.monto;
         end if;
         --Hacer el calculo por la porcion que le corresponde a la aseguradora
         v_importe := (v_tot_val_edilicio * v_val_tas_prima) / 100;

         if seg.cod_moneda <> v_cod_mon_rubro then
            v_importe := pag_gen.FU_CON_MON_A_MONEDA(seg.cod_moneda,v_cod_mon_rubro,v_importe, v_cotizacion);
         else
            v_importe := round(v_importe,v_redondeo);
         end if;

         If  seg.cod_moneda = v_cod_mon_local
         and v_importe > 100 then
           v_importe := Fu_redondear_centena(v_importe);
         end if;
         v_imp_restante := v_tot_cargo - v_importe;
         if v_imp_restante < 0 then
           v_cod_tra_movimiento := fug_obt_parentes(seg.cod_ent_seguro, 'COD_TRA_MOV_DEB_INCENDIO');
         else
           v_cod_tra_movimiento := fug_obt_parentes(seg.cod_ent_seguro, 'COD_TRA_MOV_CRE_INCENDIO');
         end if;

         --Hacer el Crédito a la Cuenta Contable
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.cod_usuario        := v_cod_usuario;
         r_gmovi.hora               := v_hora;
         r_gmovi.fecha              := v_fec_actual;
         r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
         r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
         r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
         r_gmovi.nro_cuenta         := null;
         r_gmovi.cod_moneda         := seg.cod_moneda;
         r_gmovi.est_cuenta         := null;
         r_gmovi.cod_tra_padre      := 365;
         r_gmovi.cod_transaccion    := null;
         r_gmovi.concepto           := 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
         r_gmovi.monto              := v_importe;
         if seg.cod_moneda <> v_cod_mon_local then
            v_cotizacion               := pag_gen.fu_obt_cotizacion(seg.cod_moneda, v_fec_actual);
            r_gmovi.cotizacion         := v_cotizacion;
            r_gmovi.mto_equ_local      := round(trunc(v_importe,2)*v_cotizacion,v_redondeo_ml);
         else
            v_cotizacion               := null;
            r_gmovi.cotizacion         := null;
            r_gmovi.mto_equ_local      := null;
         end if;
         r_gmovi.fec_valor          := v_fec_actual;
         r_gmovi.emi_aviso          := 'N';
         r_gmovi.reversado          := 'N';
         r_gmovi.protegido          := 'N';
         r_gmovi.estado             := 'N';
         r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
         r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
         r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
         r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01/09/10
         r_gmovi.cod_rubro          := v_cod_rubro;
         r_gmovi.tip_mov_rubro      := 'C';  --Tipo de Movimiento Crédito
         r_gmovi.val_tasa           := v_val_tas_prima;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);

      elsif v_cta_cre is not null then
         -- Traigo datos de la cuenta de la aseguradora
         pag_cta.PR_OBT_CUENTA(v_cta_cre);
         if pag_cta.G_CTAS.cod_moneda != v_cod_mon_local then
            v_tot_cargo := seg.montousd;
         else
            v_tot_cargo := seg.monto;
         end if;
         -- Hacer el calculo por la porcion que le corresponde a la aseguradora
         v_importe := (v_tot_val_edilicio * v_val_tas_prima) / 100;

         if seg.cod_moneda <> pag_cta.G_CTAS.cod_moneda then
            v_importe := pag_gen.FU_CON_MON_A_MONEDA(seg.cod_moneda,pag_cta.G_CTAS.cod_moneda,v_importe, v_cotizacion);
         else
            v_importe := round(v_importe,v_redondeo);
         end if;

         If seg.cod_moneda = v_cod_mon_local
         and v_importe > 100 then
           v_importe := Fu_redondear_centena(v_importe);
         end if;

         v_imp_restante := v_tot_cargo - v_importe;
         if v_imp_restante < 0 then
           v_cod_tra_movimiento := fug_obt_parentes(seg.cod_ent_seguro, 'COD_TRA_MOV_DEB_INCENDIO');
         else
           v_cod_tra_movimiento := fug_obt_parentes(seg.cod_ent_seguro, 'COD_TRA_MOV_CRE_INCENDIO');
         end if;

         --- Acreditar a cuenta de ahorro
         pag_cta.pr_act_operacion(v_cta_cre,
                    v_hora,--HORA
                    'C',
                    pag_cta.g_ctas.cod_moneda,      --Moneda de la Operacion
                    v_importe,
                    365,  -- COD_TRA_PADRE (Cargos por Seguros)
                    602,  -- COD_TRA_HIJO (602)
                    null, --r_pcpre.nro_cuenta,
                    v_cotizacion,  --COTIZACION
                    v_cod_ofi_origen,      --cod_ofi_origen
                    r_pcpre.cod_modulo,     --cod_mod_padre
                    r_pcpre.cod_modalidad,  --cod_mad_padre
                    null,                       --cod_tasa
                    v_val_tas_prima,            --val_tasa
                    'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta,
                    'S',                        --emi_aviso
                    v_nro_secuencia,
                    v_Fec_actual);
         if pag_cta.fu_obt_cod_error() <> 0 then
            raise_application_error(-20000, 'Acr.Seguro '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
         Else
            --- Graba el numero de comprobante para que pueda imprimir...
            If fug_obt_tip_implementacion in (1,7) then
              select s_nro_debito.nextval into v_nro_comprobante from dual;
              --
              update ge_movimientos
                set nro_documento3 = v_nro_comprobante,
                    referencia = r_pcpre.nro_cuenta   --RI:01/09/10
              where hora = v_hora
                and cod_usuario = user
                and cod_tra_padre = 365
                and concepto = 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
            End If;
         end if;
      else
         -- no existe cuenta de seguro
         raise_application_error(-20000,'Cuenta de Credito del Seguro o Escribania no definida. Verifique');
      end if;
      /*
      -- Grabar el movimiento por la porcion restante
      */
     if abs(nvl(v_imp_restante,0)) > 0 then
     v_nro_secuencia := v_nro_secuencia + 1;
     r_gmovi.nro_secuencia      := v_nro_secuencia;
     r_gmovi.cod_usuario        := v_cod_usuario;
     r_gmovi.hora               := v_hora;
     r_gmovi.fecha              := v_fec_actual;
     r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
     r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
     r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
     r_gmovi.nro_cuenta         := null;
     r_gmovi.cod_moneda         := seg.cod_moneda;
     r_gmovi.est_cuenta         := null;
     r_gmovi.cod_tra_padre      := 365;
     r_gmovi.cod_transaccion    := v_cod_tra_movimiento;
     r_gmovi.concepto           := 'Cargos por diferencia comisión - prima. Seguro de Incendio';
     r_gmovi.monto              := abs(v_imp_restante);
     if seg.cod_moneda <> v_cod_mon_local then
        v_cotizacion               := pag_gen.fu_obt_cotizacion(seg.cod_moneda, v_fec_actual);
        r_gmovi.cotizacion         := v_cotizacion;
        r_gmovi.mto_equ_local      := round(trunc(abs(v_imp_restante),2)*v_cotizacion,v_redondeo_ml);
     else
        v_cotizacion               := null;
        r_gmovi.cotizacion         := null;
        r_gmovi.mto_equ_local      := null;
     end if;
     r_gmovi.fec_valor          := v_fec_actual;
     r_gmovi.emi_aviso          := 'N';
     r_gmovi.reversado          := 'N';
     r_gmovi.protegido          := 'N';
     r_gmovi.estado             := 'N';
     r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
     r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
     r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
     r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI:01/09/10
     r_gmovi.val_tasa           := null;
     r_gmovi.cod_rubro          := null;
     r_gmovi.tip_mov_rubro      := null;
     r_gmovi.cod_persona        := sol.cod_persona;
     pag_gen.pr_ins_ge_movimiento(r_gmovi);
     end if;
    End loop;
  End loop;

-------------------------------------------------------------------------------------------------
--3  ESTA PARTE ES PARA PROCESAR LOS PRESTAMOS DE CUOTIZACION DE PRESTAMOS EN ETAPAS
--   PARA GENERAR LAS CUOTAS DE SEGURO DE INCENCIO EN TANTAS CUOTAS MENSUALES COMO
--   MESES FALTEN PARA CUMPLIRSE 12 MESES A PARTIR DEL ULTIMO DESEMBOLSO.
-------------------------------------------------------------------------------------------------
  For reg in c_sol_seg loop
     v_nro_solicitud  := reg.nro_solicitud;
     v_fec_ult_desemb := null;
     v_importe        := 0;
     --Buscar fecha del ultimo desembolso
     select max(p.fec_inicio)
       into v_fec_ult_desemb
       from pr_cta_prestamos p, pr_solicitudes s
      where s.nro_sol_original = reg.nro_sol_original
        and s.nro_solicitud <> reg.nro_solicitud
        and p.nro_solicitud = s.nro_solicitud;
     if v_fec_ult_desemb is not null then
        -- Calcular cuantos meses faltan para que se cumplan 12 meses desde la fecha
        -- del ultimo desembolso
        v_can_cuotas := 12 - trunc((reg.fec_inicio - v_fec_ult_desemb)/30);
     End if;
     --Obtener nro. cuenta del prestamo
     Begin
      Select nro_cuenta
        into v_cuenta
        from pr_sol_tasas t, pr_cta_prestamos s
       where s.nro_solicitud = v_nro_solicitud
         and t.nro_solicitud = s.nro_solicitud;
     Exception
       When others then
        raise_application_error(-20000, 'Error al traer datos del prestamo. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
     End;
     --Traer los datos del prestamo
     pap_pre.pr_obt_dat_prestamo(v_cuenta, r_pcpre);
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
     v_tot_cargo := 0;
-------------------------------------------------------------------------------------------------
--  ESTA PARTE ES PARA GENERAR LOS CARGOS POR SEGUROS EN CUOTAS - INCENDIO
-------------------------------------------------------------------------------------------------
     --Sumar el total de seguro de incendio pendiente
     Select sum(monto)
       into v_importe
       from pr_cta_gastos
      where nro_cuenta = v_cuenta
        and cod_transaccion = 1520
        and fec_ult_pago is null;
     If nvl(v_importe,0) > 0 then
       --
       -- Actualizar como pagodo las cuotas vigentes de seguro de incendio
       Update pr_cta_gastos
          set fec_ult_pago = v_fec_actual
        where nro_cuenta = v_cuenta
          and cod_transaccion = 1520
          and fec_ult_pago is null;
       --
       v_imp_cuota  := trunc(v_importe / v_can_cuotas,v_redondeo);
       --
       -- Traer la fecha de vencimiento de la cuota 0
       Begin
         Select fec_vencimiento
           into v_fec_primer_vto
            from pr_cuotas
           where nro_cuenta = v_cuenta
             and nro_cuota  = 0;
       Exception
          when others then
            raise_application_error(-20000, 'Error en Generar Mov. Seguro al traer fecha de vencimiento de cuota. '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
       End;
       --
       v_fec_vto_ant := v_fec_primer_vto;
       FOR i IN 1..v_can_cuotas LOOP
             select min(fec_vencimiento)
               into v_fec_vto
               from pr_cuotas
              where nro_cuenta = v_cuenta
                and fec_vencimiento  > v_fec_vto_ant;

             if v_fec_vto is null then
                v_fec_vto := Add_months(v_fec_vto_ant,1);
             end if;
             --
             Insert into Pr_cta_gastos
             (Nro_cuenta, Cod_transaccion, cod_moneda, Monto, Fec_ingreso,
              Fec_ini_vigencia, Fec_vencimiento, Cod_modalidad, cod_modulo,nro_solicitud)
             Values
             (r_pcpre.nro_cuenta, 1520, reg.cod_moneda, v_imp_cuota, v_fec_vto,
              v_fec_vto, null, r_pcpre.cod_modalidad, r_pcpre.cod_modulo,r_pcpre.nro_solicitud);
             --
             v_tot_cargo := nvl(v_tot_cargo,0) + nvl(v_imp_cuota,0);
             v_fec_vto_ant := v_fec_vto;
          END LOOP;
          -- Ver si hay que ajustar alguna diferencia
          if  v_tot_cargo < v_importe then
             Update pr_cta_gastos
                set monto = nvl(monto,0)+ (v_importe-v_tot_Cargo)
              where nro_cuenta = r_pcpre.nro_cuenta
                and fec_ini_vigencia = v_fec_vto;  -- la ultima
          elsif v_tot_Cargo > v_importe then
             Update pr_cta_gastos
                set monto = nvl(monto,0)- (v_tot_cargo-v_importe)
              where nro_cuenta = r_pcpre.nro_cuenta
                and fec_ini_vigencia = v_fec_vto;  -- la ultima
          end if;
     End if;
 End loop;
-------------------------------------------------------------------------------------------------
--4  ESTA PARTE ES PARA GENERAR LOS MOVIMIENTOS DE COBROS DE SEGUROS EN CUOTAS
-------------------------------------------------------------------------------------------------
 --v_hora := pag_gen.fu_obt_sig_segundo(v_hora); -- BBVASOP-1022 CB.

 v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
 v_nro_secuencia := 0;
 For reg in C_cobros loop

    if v_nro_cta_aux is null then -- BBVASOP-1022 CB.
       v_nro_cta_aux := reg.nro_cuenta;
    elsif v_nro_cta_aux <> reg.nro_cuenta then
       v_nro_cta_aux := reg.nro_cuenta;
       --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
       v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
       v_nro_secuencia := 0;
    end if;

    --PN 01/06/2015 ITGF - Rev.Histórica no Genera Mov.Inversos - SC 16659
    v_tas_prima := null;
    v_val_tas_prima := null;
    --Traer los datos del prestamo
    pap_pre.pr_obt_dat_prestamo(reg.nro_cuenta, r_pcpre);
     v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
    --Traer codigo de persona
    begin
        v_cod_persona := fug_obt_cli_principal(reg.nro_cuenta);
    exception
        when others then
          v_cod_persona := null;
    end;

   v_cod_gar_hipotecaria := fug_obt_pardinamico('COD_GAR_HIP_VIVIENDA',r_pcpre.cod_modulo,null,null,null);

   --Total Tasación de la Garantias Hipotecarias
   v_val_edilicio     := 0;
   v_val_edilicio_mon := 0;
   v_tot_val_edilicio := 0;
   for k in (select x.*
               from pr_cta_garantias x
              where x.nro_cuenta = reg.nro_cuenta
                and x.cod_garantia = v_cod_gar_hipotecaria) loop

       Declare
         Cursor c_cur is
         select cod_mon_tasacion, sum(val_edilicio) val_edilicio
           from pr_garantias g, pr_gar_hipotecarias h
          where h.nro_garantia = k.nro_garantia
            and g.nro_garantia = h.nro_garantia
       group by cod_mon_tasacion;
       Begin
         For c1 in c_cur loop
           v_val_edilicio     := c1.val_edilicio;
           v_val_edilicio_mon := c1.val_edilicio;
           If c1.cod_mon_tasacion <> r_pcpre.cod_moneda then
             v_cot1 := null;
             v_cot2 := null;
             pag_gen.pr_con_mon_a_moneda(c1.cod_mon_tasacion,
                                         r_pcpre.cod_moneda,
                                         v_val_edilicio,
                                         v_val_edilicio_mon,
                                         v_cot1,
                                         v_cot2);
             v_val_edilicio := v_val_edilicio_mon;
           end if;
         End loop;
       End;
       v_tot_val_edilicio := nvl(v_tot_val_edilicio,0) + nvl(v_val_edilicio,0);
   end loop;
    /*
    -- Generar el movimiento de debito por el porcentaje del cargo en cuenta suspenso
    */
    -- Obtiene la tasa asignada a la prima que le corresponde a la aseguradora
    If reg.cod_Transaccion = 1520 then
       v_tas_prima   := fug_obt_parentes(reg.cod_ent_seguro, 'COD_TAS_PRI_ASE_INCENDIO');
       v_tas_incendio:= fug_obt_parentes(reg.cod_ent_seguro, 'COD_TAS_SEG_INCENDIO');
       v_mto_capital := reg.monto ;             -- v_tot_val_edilicio;
       -- 04/06/2014-OMM - Se ajusto por diferencias en la afectación del rubro de ganancias
       if  v_tas_incendio is not null then
          PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,r_pcpre.cod_modalidad,r_pcpre.cod_oficina,
                 r_pcpre.nro_cuenta,  r_pcpre.cod_moneda, nvl(reg.monto,0),
                 'N', v_tas_incendio,  NULL, r_pcpre.fec_inicio, v_val_tas_incendio,v_fec_vigencia,
                 v_tip_valor, v_tipo);
          if v_val_tas_incendio is null then
            raise_application_error(-20000,'No encuentra valor de la tasa global del seguro de Incendio. Verifique');
          end if;
       else
          raise_application_error(-20000,'No encuentra código de la tasa global. Verifique');
       end if;

    elsif reg.cod_Transaccion = 1521 then

       /*ITGF - Diferencia - Rubro Seguro a Cobrar SC 10441 PMN: se obtienen las tasas
         ingresadas a fin de mes por prp_gen_car_seg_vida */
       Select fec_vencimiento
         into v_fec_ven_cuota
         from pr_cuotas
        where nro_cuenta = reg.nro_cuenta
          and nro_cuota = reg.nro_documento3;


       begin
         select cod_tas_ref1, val_tas_ref1, cod_tas_ref2, val_tas_ref2
           into v_cod_tas_seg_vida, v_val_tas_seg_vida, v_tas_prima, v_val_tas_prima
           from pr_cta_gastos c
          where c.nro_cuenta = reg.nro_cuenta
            and c.fec_ult_pago = reg.fecha
            and c.hor_ult_pago = reg.hora
            and c.cod_transaccion = reg.cod_transaccion
            and c.fec_ini_vigencia = v_fec_ven_cuota;
       exception
         when others then
           v_cod_tas_seg_vida := null;
           v_val_tas_seg_vida := null;
           v_tas_prima := null;
           v_val_tas_prima := null;
       end;

       begin
           select cod_ent_seguro
             into v_cod_ent_seguro
             from pr_sol_cargos s, pr_cta_prestamos p
            where nro_cuenta = reg.nro_cuenta
              and s.nro_solicitud = p.nro_solicitud
              and cod_transaccion = 1521;
       exception
            when no_data_found then
              v_cod_ent_seguro := FUG_OBT_ENT_SEGURO(6, reg.cod_modalidad, 'V');
            when others then
              raise_application_error(-20000,
                          'No encuentra código de Aseguradora. Verifique la solicitud del prestamo '||reg.nro_cuenta);
       end;

       if v_tas_prima is null then
          v_tas_prima   := fug_obt_parentes(v_cod_ent_seguro, 'COD_TAS_PRI_ASE_VIDA');
       end if;
       v_mto_capital := r_pcpre.sal_cap_batch;  -- r_pcpre.sal_capital ;


    End if;
    -- Obtener fecha de inicio y vencimiento del prestamo.
    begin
      select a.fec_vencimiento, a.fec_inicio
        into v_fec_vencimiento, v_fec_inicio
        from pr_cta_prestamos a
       where a.nro_cuenta = reg.nro_cuenta;
    end;
    if reg.cod_transaccion <> 703 then
    if v_val_tas_prima is null then
      if  v_tas_prima is not null then
        PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,r_pcpre.cod_modalidad,r_pcpre.cod_oficina,
                   r_pcpre.nro_cuenta,  r_pcpre.cod_moneda, nvl(reg.monto,0), --(r_pcpre.fec_vencimiento-r_pcpre.fec_inicio),
                   'N', v_tas_prima,  NULL, r_pcpre.fec_inicio, v_val_tas_prima,v_fec_vigencia,
                   v_tip_valor, v_tipo);

            if v_val_tas_prima is null then
              raise_application_error(-20000,'No encuentra valor de la tasa del seguro de Incendio. Verifique');
            end if;
      else
           raise_application_error(-20000,'No encuentra código de la tasa. Verifique');
      end if;
   end if;
   end if;
   -- Hacer el calculo por la porcion que le corresponde a la aseguradora
     If reg.cod_Transaccion = 1520 then
        v_importe := round((v_mto_capital * ((100 * v_val_tas_prima)/v_val_tas_incendio)) / 100,v_redondeo);
     else
        --v_importe := round((v_mto_capital * v_val_tas_prima) / 100,v_redondeo);
         /*ITGF - Diferencia - Rubro Seguro a Cobrar SC 10441 PMN: Se modifica la forma
           en que calcula el valor de la comision */

        if v_cod_tas_seg_vida is null then


            v_cod_tas_seg_vida := fug_obt_parentes(v_cod_ent_seguro,'COD_TAS_SEG_VIDA');


            PAG_GEN.PR_OBT_VAL_TASA(r_pcpre.cod_modulo,r_pcpre.cod_modalidad,r_pcpre.cod_oficina,
                                    r_pcpre.nro_cuenta,  r_pcpre.cod_moneda,(r_pcpre.fec_vencimiento-r_pcpre.fec_inicio),
                                    'N', v_cod_tas_seg_vida,  NULL, r_pcpre.fec_inicio, v_val_tas_seg_vida,v_fec_vigencia,
                                     v_tip_valor, v_tipo);

            if v_val_tas_seg_vida is null then
              raise_application_error(-20000,'No encuentra valor de la tasa del seguro de vida. Verifique');
            end if;
        end if;

        v_importe := round(reg.monto * v_val_tas_prima / v_val_tas_seg_vida, v_redondeo);
        -- Para redondear la porción de la aseguradora.
        --ITGF - Diferencias en Saldos de Inventario y Saldos Contables en el Rubro Seguro de Vida por Cobrar -SC 13187
        /*If r_pcpre.cod_moneda = v_cod_mon_local  and v_importe > 100 then
           v_importe := fu_redondear_centena(v_importe);
        end if;*/
     end if ;
     if v_val_tas_prima = v_val_tas_seg_vida then
        v_imp_restante := 0;
     else
        v_imp_restante := reg.monto - v_importe;
     end if;

    -- OMM 20/09/2011 No generar Movimientos con monto Cero
    if nvl(abs(v_imp_restante),0) > 0 then
        If  reg.Cod_Transaccion = 1520 then   -- Incendio
          v_tra_padre       := 366;
          v_cod_transaccion := 1522;
        elsif reg.cod_Transaccion = 1521 then  -- Vida
          v_tra_padre       := 370;
          v_cod_transaccion := 1525;
        end if;

        -- Se mueve aca está porcion para obtener el cargo de iva  DYDMR-6544 16/10/2017
         -- Se calcula el I.V.A.   s/ el Cargo ---------------------------------
        v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, 517, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
        -- RI : 03/06/2010 : El cargo de seguro es iva incluido, se debe desglosar

        v_cargo_iva := round(nvl(reg.monto,0)*nvl(v_val_tasa,0)/(100+v_val_tasa),v_redondeo);
        ------------------------------------------------------------------------


       -- Inserta el movimiento
        if v_nro_secuencia > 990 then
          --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
          v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
          v_nro_secuencia := 0;
        end if;
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := v_cod_transaccion; -- Debito por el porcentaje del cargo, cuenta suspenso
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
        r_gmovi.monto              := abs(v_imp_restante);
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(abs(v_imp_restante),2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
        r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
        r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI:01/09/10
        r_gmovi.cod_tasa           := null;
        r_gmovi.val_tasa           := null;
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
           ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        /*
        -- Grabar el movimiento por la diferencia a cuenta ganancia
        */
        v_importe := abs(v_imp_restante) - v_cargo_iva;

        If  reg.Cod_Transaccion = 1520 then   -- Incendio
          v_cod_transaccion := 1632;
        elsif reg.cod_Transaccion = 1521 then  -- Vida
          v_cod_transaccion := 1633;
        end if;
        --
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;
        r_gmovi.cod_transaccion    := v_cod_Transaccion;
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
        r_gmovi.monto              := v_importe;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_importe,2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
        r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := null;
        r_gmovi.val_tasa           := null;
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
            ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        --
        /*
        -- Generar el movimiento de credito por el IVA del total del cargo
        */
        -- Se calcula el I.V.A.   s/ el Cargo
        /*v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, 517, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
        -- RI : 03/06/2010 : El cargo de seguro es iva incluido, se debe desglosar

        v_cargo_iva := round(nvl(reg.monto,0)*nvl(v_val_tasa,0)/(100+v_val_tasa),v_redondeo);*/
        v_nro_secuencia := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := reg.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := 1631;  -- Credito por el IVA del total del cargo
        r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
        r_gmovi.monto              := v_cargo_iva;
        if reg.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_cargo_iva,2)*v_cotizacion,v_redondeo_ml);
        else
           v_cotizacion               := null;
           r_gmovi.cotizacion         := null;
           r_gmovi.mto_equ_local      := null;
        end if;
        r_gmovi.fec_valor          := v_fec_actual;
        r_gmovi.emi_aviso          := 'N';
        r_gmovi.reversado          := 'N';
        r_gmovi.protegido          := 'N';
        r_gmovi.estado             := 'N';
        r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
        r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
        r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
        r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
        r_gmovi.cod_tasa           := v_cod_tasa;
        r_gmovi.val_tasa           := v_val_tasa; --Se agrego el valor de la tasa para generar el libro de ventas JF 31/08/2011.-
        r_gmovi.cod_rubro          := null;
        r_gmovi.tip_mov_rubro      := null;
        r_gmovi.cod_persona        := v_cod_persona;
          ----- ajuste---
        r_gmovi.nro_documento      := reg.nro_documento;
        r_gmovi.nro_documento2     := reg.nro_documento2;
        r_gmovi.nro_documento3     := reg.nro_documento3;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
        --DYDMR-3242 ITGF - Cobro de Cargos de Seguro de Vida - No se Generó Factura SC 26223 (URGENTE)
      else
        If  reg.Cod_Transaccion in (1520, 1521) then
        -- DYDMR-9146 Incidencia SAU - ITGF - Factura por Seguro de Vida
          If  reg.Cod_Transaccion = 1520 then   -- Incendio
            v_tra_padre       := 366;
            v_cod_transaccion := 1520;
          elsif reg.cod_Transaccion = 1521 then  -- Vida
            v_tra_padre       := 370;
            v_cod_transaccion := 1521;
          end if;
          /*
          -- Generar el movimiento de credito por el IVA del total del cargo
          */
          -- Se calcula el I.V.A.   s/ el Cargo
          if v_nro_secuencia > 990 then
            v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
            v_nro_secuencia := 0;
          end if;

          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad,
                                  r_pcpre.cod_oficina, r_pcpre.nro_cuenta, r_pcpre.cod_moneda,
                                  0, 'N', v_cod_tasa, 517, --Transaccion
                                  pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
          -- RI : 03/06/2010 : El cargo de seguro es iva incluido, se debe desglosar

          v_cargo_iva := round(nvl(reg.monto,0)*nvl(v_val_tasa,0)/(100+v_val_tasa),v_redondeo);
          --
          v_nro_secuencia := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.cod_usuario        := v_cod_usuario;
          r_gmovi.hora               := v_hora;
          r_gmovi.fecha              := v_fec_actual;
          r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
          r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
          r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
          r_gmovi.nro_cuenta         := null;
          r_gmovi.cod_moneda         := reg.cod_moneda;
          r_gmovi.est_cuenta         := null;
          r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
          r_gmovi.cod_transaccion    := 1631;  -- Credito por el IVA del total del cargo
          r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
          r_gmovi.monto              := v_cargo_iva;
          if reg.cod_moneda <> v_cod_mon_local then
             v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
             r_gmovi.cotizacion         := v_cotizacion;
             r_gmovi.mto_equ_local      := round(trunc(v_cargo_iva,2)*v_cotizacion,v_redondeo_ml);
          else
             v_cotizacion               := null;
             r_gmovi.cotizacion         := null;
             r_gmovi.mto_equ_local      := null;
          end if;
          r_gmovi.fec_valor          := v_fec_actual;
          r_gmovi.emi_aviso          := 'N';
          r_gmovi.reversado          := 'N';
          r_gmovi.protegido          := 'N';
          r_gmovi.estado             := 'N';
          r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
          r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
          r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
          r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
          r_gmovi.cod_tasa           := v_cod_tasa;
          r_gmovi.val_tasa           := v_val_tasa; --Se agrego el valor de la tasa para generar el libro de ventas JF 31/08/2011.-
          r_gmovi.cod_rubro          := null;
          r_gmovi.tip_mov_rubro      := null;
          r_gmovi.cod_persona        := v_cod_persona;
            ----- ajuste---
          r_gmovi.nro_documento      := reg.nro_documento;
          r_gmovi.nro_documento2     := reg.nro_documento2;
          r_gmovi.nro_documento3     := reg.nro_documento3;
          pag_gen.pr_ins_ge_movimiento(r_gmovi);

          -- Se descuenta el movimiento del iva al cargo de seguro de vida generado.
          v_nro_secuencia := v_nro_secuencia + 1;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.cod_usuario        := v_cod_usuario;
          r_gmovi.hora               := v_hora;
          r_gmovi.fecha              := v_fec_actual;
          r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
          r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
          r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
          r_gmovi.nro_cuenta         := null;
          r_gmovi.cod_moneda         := reg.cod_moneda;
          r_gmovi.est_cuenta         := null;
          r_gmovi.cod_tra_padre      := v_tra_padre;  -- Cobro de Cargos por seguro en cuotas
          r_gmovi.cod_transaccion    := v_cod_transaccion;  -- Credito por el IVA del total del cargo
          r_gmovi.concepto           := 'Cobro de Cargos de Seguros en cuotas';
          r_gmovi.monto              := v_cargo_iva * -1;
          if reg.cod_moneda <> v_cod_mon_local then
             v_cotizacion               := pag_gen.fu_obt_cotizacion(reg.cod_moneda, v_fec_actual);
             r_gmovi.cotizacion         := v_cotizacion;
             r_gmovi.mto_equ_local      := round(trunc(v_cargo_iva*-1,2)*v_cotizacion,v_redondeo_ml);
          else
             v_cotizacion               := null;
             r_gmovi.cotizacion         := null;
             r_gmovi.mto_equ_local      := null;
          end if;
          r_gmovi.fec_valor          := v_fec_actual;
          r_gmovi.emi_aviso          := 'N';
          r_gmovi.reversado          := 'N';
          r_gmovi.protegido          := 'N';
          r_gmovi.estado             := 'N';
          r_gmovi.cod_ofi_origen     := v_cod_ofi_origen;
          r_gmovi.cod_mod_padre      := r_pcpre.cod_modulo;
          r_gmovi.cod_mad_padre      := r_pcpre.cod_modalidad;
          r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
          r_gmovi.cod_tasa           := v_cod_tasa;
          r_gmovi.val_tasa           := v_val_tasa; --Se agrego el valor de la tasa para generar el libro de ventas JF 31/08/2011.-
          r_gmovi.cod_rubro          := null;
          r_gmovi.tip_mov_rubro      := null;
          r_gmovi.cod_persona        := v_cod_persona;
            ----- ajuste---
          r_gmovi.nro_documento      := reg.nro_documento;
          r_gmovi.nro_documento2     := reg.nro_documento2;
          r_gmovi.nro_documento3     := reg.nro_documento3;
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
       end if;
      end if;
    End loop;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar cargos en cuotas por seguros.  Error : '||v_cuenta||' '||sqlerrm);
END;
/
