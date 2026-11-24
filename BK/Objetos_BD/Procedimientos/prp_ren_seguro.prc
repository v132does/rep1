CREATE OR REPLACE PROCEDURE IT.PRP_REN_SEGURO (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE) is
  --- PARA CASOS QUE NO FUERON GENERADOS AUTOMATICAMENTE POR PROBLEMAS DE DTOS ----  DM 10-07-2012
  --Renovación Seguros de Incendio para Préstamos Hipotecarios, recibe Nro. de Cuenta y
  --genera las cuotas del Seguro y Realiza el crédito de la Prima para la Aseguradora.
  --Declaración de Variables
  v_val_edilicio         pr_gar_hipotecarias.val_edilicio%type := 0;
  v_val_edilicio_mon     pr_gar_hipotecarias.val_edilicio%type := 0;
  v_tot_val_edilicio     pr_gar_hipotecarias.val_edilicio%type := 0;
  v_cot1                 number;
  v_cot2                 number;
  v_fec_actual           date := pag_cal.fu_obt_fec_actual(6);
  v_cod_gar_hipotecaria  number;
  v_can_cuotas           number;
  v_cod_tasa             ge_tasas.cod_tasa%type;
  v_fec_vigencia         date;
  v_val_tasa             ge_movimientos.val_tasa%type;
  v_tip_valor            ge_tasas.tip_valor%type;
  v_tipo                 ge_tasas.tipo%type;
  v_redondeo             number;
  v_mto_equivalente      number;
  v_mto_cargo            number;
  v_cotizacion           ge_movimientos.cotizacion%type;
  v_cod_mon_local        ge_movimientos.cod_moneda%type  := pag_gen.fu_obt_mon_local;
  v_redondeo_ml          number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, pag_gen.fu_obt_mon_local);
  v_fec_primer_vto       date;
  v_imp_cuota            number;
  v_fec_vto              date;
  v_tot_cargo            number;
  v_nro_secuencia        ge_movimientos.nro_secuencia%type := 0;
  v_cod_usuario          ge_movimientos.cod_usuario%type := user;
  v_hora                 ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_cod_ofi_origen       ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);
  v_cta_cre              ge_movimientos.nro_cuenta%type;
  v_porc_char            varchar2(8);
  v_porc_aseg            number;
  v_importe              number;
  v_imp_restante         number;
  v_nro_comprobante      ge_movimientos.nro_documento3%type;
  v_nro_solicitud        pr_solicitudes.nro_solicitud%type;
  v_ctcuota              number;
  v_sum_dias             number;
  v_can_cuo_pend         number;
  v_fec_vto_ant          date;

  --Variables de registro
  r_pcpre                pr_cta_prestamos%rowtype;
  r_gmovi                ge_movimientos%rowtype;
  r_psoli                pr_solicitudes%rowtype;
  r_pscar                pr_sol_cargos%rowtype;

  v_cod_rubro       cb_rubros.cod_rubro%type;
  v_cod_mon_rubro   cb_rubros.cod_moneda%type;

  --Función Local para redondeo
  function lf_redondear_centena(p_importe in number)  return number is
  v_imp number;
  v_imp_cen number;

  begin
    if p_importe/100 = trunc(p_importe/100) then
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
  end;

begin

   --Obtener Cantidad de Cuotas del parámetro dinámico
   v_can_cuotas    := nvl(fug_obt_pardinamico('CAN_CUO_SEG_INCENDIO'),12);
   v_hora          := nvl(pae_cnf.g_hora, fug_ini_hora(sysdate,'hh24:mi:ss'));
   v_nro_secuencia := nvl(pae_cnf.g_nro_secuencia,0);

   if v_nro_secuencia > 990 then
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      v_nro_secuencia := 0;
      --Volver a setear las variables
      pae_cnf.pr_set_variables(v_hora,v_nro_secuencia);
   end if;

   --Obtener Datos del Préstamo
   begin
     select *
       into r_pcpre
       from pr_cta_prestamos k
      where k.nro_cuenta = p_nro_cuenta;
   exception
     when no_data_found then
       raise_application_error(-20000, 'No se encuentran datos del Préstamo.  Error : '||sqlerrm);
     when others then
       raise_application_error(-20000, 'Error al obtener datos del Préstamo.  Error : '||sqlerrm);
   end;
    v_nro_solicitud  := r_pcpre.nro_solicitud;

   --Validar Estado de la Cuenta
   --RI: 03/11/2010: Se debe renovar en cualquier estado en que se encuentre el prestamo
   --a excepcion del estado Incobrable
   --if r_pcpre.estado not in ('C') then --Estados que permiten renovación
   If r_pcpre.estado = 'I' then
      raise_application_error(-20000, 'No se puede renovar el Seguro de un Préstamo en estado ('||r_pcpre.estado||')' );
   end if;

   --Obtener datos de la solicitud
   begin
     select *
       into r_psoli
       from pr_solicitudes s
      where s.nro_solicitud = r_pcpre.nro_solicitud;
   exception
     when no_data_found then
       raise_application_error(-20000, 'No se encuentran datos de la Solicitud.  Error : '||sqlerrm);
     when others then
       raise_application_error(-20000, 'Error al obtener datos de la Solicitud.  Error : '||sqlerrm);
   end;

   v_cod_gar_hipotecaria := fug_obt_pardinamico('COD_GAR_HIPOTECARIA',r_pcpre.cod_modulo,null,null,null);

   --Total Tasación de la Garantias Hipotecarias
   v_val_edilicio     := 0;
   v_val_edilicio_mon := 0;
   v_tot_val_edilicio := 0;
   for k in (select x.*
               from pr_cta_garantias x   --RI: 29/07/2010: se cambio la tabla pr_sol_garantias por Pr_cta_garantias
              where x.nro_cuenta = p_nro_cuenta
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

   --Datos del Cargo
   select *
     into r_pscar
     from pr_sol_cargos c
    where c.nro_solicitud = r_pcpre.nro_solicitud
      and c.cod_transaccion = 1520; -- Seguro de Incendio

   --Obtener Valor de Tasa
   v_cod_tasa := fug_obt_parentes(r_pscar.cod_ent_seguro,'COD_TAS_SEG_INCENDIO');

   pag_gen.pr_obt_val_tasa(r_psoli.cod_modulo, r_psoli.cod_modalidad, r_psoli.cod_oficina,
                           null ,r_psoli.cod_moneda, null , 'S', v_cod_tasa, null , v_fec_actual,
                           v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo, r_psoli.cod_persona);

   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_psoli.cod_modulo, r_psoli.cod_modalidad, r_psoli.cod_moneda, r_psoli.cod_oficina);
   v_mto_equivalente := round(v_tot_val_edilicio * v_val_tasa / 100,v_redondeo);
   v_cotizacion := pag_gen.fu_obt_cotizacion(r_pscar.cod_moneda, v_fec_actual);

   if r_pscar.cod_moneda = r_psoli.cod_moneda then
      v_mto_cargo := v_mto_equivalente;
   else
      v_mto_cargo := round(v_mto_equivalente * v_cotizacion,v_redondeo);
   end if;

   --RI: 29/07/2010: Procesar solo si el cargo es mayor a cero.
   If  v_mto_Cargo > 0 then
     --Actualizar valores del cargo en PR_SOL_CARGOS
     update pr_sol_cargos s
        set s.val_tasa = v_val_tasa,
            s.cod_tasa  = v_cod_tasa,
            s.monto = v_mto_cargo,
            s.mto_mon_prestamo = v_mto_equivalente
      where s.nro_solicitud = r_pscar.nro_solicitud
        and s.cod_transaccion = r_pscar.cod_transaccion;

     select count(1)
       into v_can_cuo_pend
       from pr_cuotas
      where fec_vencimiento > v_fec_actual;

     --Si faltan menos de 12 cuotas para finalizar el préstamo Ajustar la Cantidad de Cuotas
     if v_can_cuo_pend < v_can_cuotas then
        v_can_cuotas := v_can_cuo_pend;
     end if;

     --Generar las cuotas de Seguro
     v_imp_cuota  := trunc(v_mto_cargo / v_can_cuotas,v_redondeo);

     --Traer la fecha de vencimiento de la última cuota del seguro actual
     Begin
       Select max(fec_ini_vigencia)
         into v_fec_primer_vto
         from pr_cta_gastos
        where nro_cuenta = p_nro_cuenta
          and cod_transaccion = 1520;
     Exception
         when others then
           raise_application_error(-20000, 'Error al Buscar la fecha de Vencimiento del Seguro.');
     End;

    if v_fec_primer_vto > v_fec_actual then
       raise_application_error(-20000, 'Error: El Seguro actual aún no esta Vencido.');
    else
      v_fec_primer_vto := v_fec_actual; ----- primer vencimiento es la fecha actual  DM
     end if;
     --

      v_fec_vto_ant := v_fec_primer_vto;
      for i in 1..v_can_cuotas loop

         select min(fec_vencimiento)
           into v_fec_vto
           from pr_cuotas
          where nro_cuenta = r_pcpre.nro_cuenta
            and fec_vencimiento > v_fec_vto_ant;

         if v_fec_vto is null then
            v_fec_vto := Add_months(v_fec_vto_ant,1);
         end if;

         --
         insert into pr_cta_gastos
         (nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
          fec_ini_vigencia, fec_vencimiento, cod_modalidad, cod_modulo, nro_solicitud)
         values
         (r_pcpre.nro_cuenta, r_pscar.cod_transaccion, r_pscar.cod_moneda, v_imp_cuota, v_fec_vto,
          v_fec_vto, null, r_pcpre.cod_modalidad, r_pcpre.cod_modulo, r_pcpre.nro_solicitud);
         --
         v_tot_cargo := nvl(v_tot_cargo,0) + nvl(v_imp_cuota,0);
         v_fec_vto_ant := v_fec_vto;
      end loop;
      --Ver si hay que ajustar alguna diferencia
      if v_tot_cargo < v_mto_cargo then
         update pr_cta_gastos
            set monto = nvl(monto,0)+ (v_mto_cargo-v_tot_cargo)
          where nro_cuenta = r_pcpre.nro_cuenta
            and fec_ini_vigencia = v_fec_vto;  --La ultima
      elsif v_tot_Cargo > v_mto_cargo then
         update pr_cta_gastos
            set monto = nvl(monto,0)- (v_tot_cargo-v_mto_cargo)
          where nro_cuenta = r_pcpre.nro_cuenta
            and fec_ini_vigencia = v_fec_vto;  --La ultima
      end if;
      ---------------------------------------------------------------------------------------------------
      ---ESTA PARTE ES PARA GENERAR LOS MOVIMIENTOS QUE CORRESPONDEN POR LOS CARGOS Y EL CREDITO EN LA
      ---CUENTA DE LA PROCESADORA
      ---------------------------------------------------------------------------------------------------

        --Generar el movimiento por el total del cargo por seguro
        v_nro_secuencia            := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia      := v_nro_secuencia;
        r_gmovi.cod_usuario        := v_cod_usuario;
        r_gmovi.hora               := v_hora;
        r_gmovi.fecha              := v_fec_actual;
        r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
        r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
        r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
        r_gmovi.nro_cuenta         := null;
        r_gmovi.cod_moneda         := r_pscar.cod_moneda;
        r_gmovi.est_cuenta         := null;
        r_gmovi.cod_tra_padre      := 365;   --Cargos por seguro en cuotas
        r_gmovi.cod_transaccion    := 1523;  --Debito por cargo de seguros a cuenta en suspenso
        r_gmovi.concepto           := 'Cargos por Seguro de Incendio';
        r_gmovi.monto              := v_mto_cargo;
        if r_pscar.cod_moneda <> v_cod_mon_local then
           v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pscar.cod_moneda, v_fec_actual);
           r_gmovi.cotizacion         := v_cotizacion;
           r_gmovi.mto_equ_local      := round(trunc(v_mto_cargo,2)*v_cotizacion,v_redondeo_ml);
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
        --r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
        r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01/09/10
        r_gmovi.val_tasa           := v_val_tasa;
        r_gmovi.cod_persona        := r_psoli.cod_persona;
        pag_gen.pr_ins_ge_movimiento(r_gmovi);

        --Esta parte corresponde al crédito del monto a pagar a la Aseguradora
        --en su cuenta
        begin
           v_cta_cre := null;
           if fug_obt_tip_ente(r_pscar.cod_ent_seguro) = 'SE' then
              if r_pscar.cod_moneda = v_cod_mon_local then
                 v_cta_cre := fug_obt_parentes(r_pscar.cod_ent_seguro, 'NRO_CTA_SEG_MON_LOCAL');
                 v_cod_rubro := fug_obt_parentes(r_pscar.cod_ent_seguro, 'COD_RUB_MON_LOCAL');
              else
                 v_cta_cre := fug_obt_parentes(r_pscar.cod_ent_seguro, 'NRO_CTA_SEG_MON_FUERTE');
                 v_cod_rubro := fug_obt_parentes(r_pscar.cod_ent_seguro, 'COD_RUB_MON_FUERTE');
              end if;
           else
              v_cta_cre := fug_obt_parentes(r_pscar.cod_ent_seguro, 'NRO_CTA_ESCRIBANIA');
           end if;
        exception
           when others then v_cta_cre := null;
        end;

        -- Traigo el porcentaje de la prima que le corresponde a la aseguradora
        v_porc_char := fug_obt_parentes(r_pscar.cod_ent_seguro, 'POR_PRI_ASE_INCENDIO');
        if instr(v_porc_char,'.') <> 0 then
          v_porc_aseg := to_number(v_porc_char,'999.99');
        elsif  instr(v_porc_char,',') <> 0 then
          v_porc_aseg := to_number(v_porc_char,'999,99');
        else
          v_porc_Aseg := to_number(v_porc_char);
        end if;
        --Si en los Parámetros del Ente esta configurado un Rubro Contable se realiza el Crédito a este Rubro
        if v_cod_rubro is not null then
           v_cod_mon_rubro := pag_sue.fu_obt_mon_rubro(v_cod_rubro);
           if v_cod_mon_rubro != v_cod_mon_local then
              v_tot_cargo := v_mto_equivalente;
           else
              v_tot_cargo := v_mto_cargo;
           end if;
           --Hacer el calculo por la porcion que le corresponde a la aseguradora
           v_importe := (v_tot_cargo * v_porc_aseg) / 100;

           if r_pscar.cod_moneda <> v_cod_mon_rubro then
              v_importe := pag_gen.FU_CON_MON_A_MONEDA(r_pscar.cod_moneda,pag_cta.G_CTAS.cod_moneda,v_importe, v_cotizacion);
           else
              v_importe := round(v_importe,v_redondeo);
           end if;

           If r_pcpre.cod_moneda = v_cod_mon_local
           and v_importe > 100 then
             v_importe := lf_redondear_centena(v_importe);
           end if;
           v_imp_restante := v_tot_cargo - v_importe;

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
           r_gmovi.cod_moneda         := r_pscar.cod_moneda;
           r_gmovi.est_cuenta         := null;
           r_gmovi.cod_tra_padre      := 365;
           r_gmovi.cod_transaccion    := null;
           r_gmovi.concepto           := 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
           r_gmovi.monto              := v_importe;
           if r_pscar.cod_moneda <> v_cod_mon_local then
              v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pscar.cod_moneda, v_fec_actual);
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
           --r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
           r_gmovi.referencia         := r_pcpre.nro_cuenta; --RI: 01/09/10
           r_gmovi.cod_rubro          := v_cod_rubro;
           r_gmovi.tip_mov_rubro      := 'C';  --Tipo de Movimiento Crédito
           r_gmovi.val_tasa           := null;
           pag_gen.pr_ins_ge_movimiento(r_gmovi);
        elsif v_cta_cre is not null then

           --Traigo datos de la cuenta de la Aseguradora
           pag_cta.pr_obt_cuenta(v_cta_cre);
           if pag_cta.g_ctas.cod_moneda != v_cod_mon_local then
              v_tot_cargo := v_mto_equivalente;
           else
              v_tot_cargo := v_mto_cargo;
           end if;
           --Hacer el calculo por la porcion que le corresponde a la aseguradora
           v_importe := (v_tot_cargo * v_porc_aseg) / 100;

           if r_pscar.cod_moneda <> pag_cta.g_ctas.cod_moneda then
              v_importe := pag_gen.FU_CON_MON_A_MONEDA(r_pscar.cod_moneda,pag_cta.G_CTAS.cod_moneda,v_importe, v_cotizacion);
           else
              v_importe := round(v_importe,v_redondeo);
           end if;

           If r_pcpre.cod_moneda = v_cod_mon_local
           and v_importe > 100 then
             v_importe := lf_redondear_centena(v_importe);
           end if;
           v_imp_restante := v_tot_cargo - v_importe;

           --Acreditar a cuenta de ahorro
           pag_cta.pr_act_operacion(v_cta_cre,
                                    v_hora,                   --HORA
                                    'C',
                                    pag_cta.g_ctas.cod_moneda,--MONEDA DE LA OPERACION
                                    v_importe,
                                    365,                      --COD_TRA_PADRE (Cargos por Seguros)
                                    602,                      --COD_TRA_HIJO (602)
                                    r_pcpre.nro_cuenta,
                                    v_cotizacion,             --COTIZACION
                                    v_cod_ofi_origen,         --COD_OFI_ORIGEN
                                    r_pcpre.cod_modulo,       --COD_MOD_PADRE
                                    r_pcpre.cod_modalidad,    --COD_MAD_PADRE
                                    null,                     --COD_TASA
                                    null,                     --VAL_TASA
                                    'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta,
                                    'S',                      --EMI_AVISO
                                    v_nro_secuencia,
                                    v_Fec_actual);
           if pag_cta.fu_obt_cod_error() <> 0 then
              raise_application_error(-20000, 'Acr.Seguro '||pag_cta.fu_obt_cod_error()||  ' - '|| pag_cta.fu_obt_msj_error());
           else
             --Graba el número de comprobante para que pueda imprimir...
             If fug_obt_tip_implementacion in (1,7) then
                select s_nro_debito.nextval into v_nro_comprobante from dual;
                ---
                update ge_movimientos
                   set nro_documento3 = v_nro_comprobante,
                       referencia     = r_pcpre.nro_cuenta  --RI: 01/09/10
                 where hora = v_hora
                   and cod_usuario = user
                   and cod_tra_padre = 365
                   and concepto = 'Credito por Cargos de Seguro '||r_pcpre.nro_cuenta;
             End If;
           end if;
        else
           --No existe cuenta de seguro
           raise_application_error(-20000,'Cuenta de Crédito del Seguro o Escribania no definida. Verifique');
        end if;

       --Grabar el movimiento por la porción restante
       v_nro_secuencia            := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia      := v_nro_secuencia;
       r_gmovi.cod_usuario        := v_cod_usuario;
       r_gmovi.hora               := v_hora;
       r_gmovi.fecha              := v_fec_actual;
       r_gmovi.cod_modulo         := r_pcpre.cod_modulo;
       r_gmovi.cod_modalidad      := r_pcpre.cod_modalidad;
       r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
       r_gmovi.nro_cuenta         := null;
       r_gmovi.cod_moneda         := r_pscar.cod_moneda;
       r_gmovi.est_cuenta         := null;
       r_gmovi.cod_tra_padre      := 365;
       r_gmovi.cod_transaccion    := 1630;
       r_gmovi.concepto           := 'Cargos por Seguro de Incendio';
       r_gmovi.monto              := v_imp_restante;
       if r_pscar.cod_moneda <> v_cod_mon_local then
          v_cotizacion               := pag_gen.fu_obt_cotizacion(r_pscar.cod_moneda, v_fec_actual);
          r_gmovi.cotizacion         := v_cotizacion;
          r_gmovi.mto_equ_local      := round(trunc(v_imp_restante,2)*v_cotizacion,v_redondeo_ml);
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
       --r_gmovi.nro_documento      := r_pcpre.nro_cuenta;
       r_gmovi.referencia         := r_pcpre.nro_cuenta;  --RI: 01/09/10
       r_gmovi.val_tasa           := null;
       r_gmovi.cod_rubro          := null;
       r_gmovi.tip_mov_rubro      := null;
       r_gmovi.cod_persona        := r_psoli.cod_persona;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
  End if;

  --RI: 03/11/2010 : Volver a setear las variables
  pae_cnf.pr_set_variables(v_hora,v_nro_secuencia);

end PRP_REN_SEGURO;
/

