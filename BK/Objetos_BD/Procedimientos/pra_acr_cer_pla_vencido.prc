CREATE OR REPLACE PROCEDURE IT.PRA_ACR_CER_PLA_VENCIDO
 Is
/* Acreditar cda */
PROCEDURE LP_ACR_CERTIFICADO(P_NRO_CUENTA IN NUMBER);

   v_fec_actual      ge_calendarios.fec_actual%type;
   v_cod_mon_local   ba_monedas.cod_moneda%type;
   v_hora            ge_movimientos.hora%type := TO_CHAR(SYSDATE,'HH24:MI:SS');
   v_nro_secuencia   ge_movimientos.nro_secuencia%type;
   v_est_modulo      ba_modulos.estado%type := pae_cnf.FU_OBT_EST_MODULO(3);
   v_es_nocturno     varchar2(1) := 'N';

   --- Cursor de plazo dig a vencer
   cursor c_certificados is
   select nro_cuenta
     from ah_cta_plazos
    where fec_vencimiento <= v_fec_actual
      --and est_certificado = 'E'
      and cod_modalidad = 37
      and estado not in ('C','T','P','A','X');

   --- Cursor de plazos dig vencidos
   cursor c_pla_vencidos is
   select a.nro_cuenta, a.cod_moneda, a.sal_total, a.nro_cta_capitalizacion, a.cod_modulo, 
          a.cod_modalidad, a.cod_oficina
     from ah_cta_plazos a
    where fec_vencimiento <= v_fec_actual
      and a.estado = 'V'
      and cod_modalidad = 37
      and estado not in ('C','T','P','A','X');
      
/* Acreditar plazo dig */
PROCEDURE LP_ACR_CERTIFICADO(P_NRO_CUENTA IN NUMBER) IS
   r_gmovi           ge_movimientos%rowtype;
   v_mon_pignorado   ge_bloqueos.monto%type := 0;
   --v_cod_mon_local   ba_monedas.cod_moneda%type;
   --v_cot_mon_ori     ge_cotizaciones.val_compra%type;
BEGIN
   --- Recuperar moneda local
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   /*update AH_CTA_CERTIFICADOS
      set EST_CERTIFICADO = 'V'
    where NRO_CUENTA = pag_cta.g_ctas.nro_cuenta;*/
   --- Insertar movimiento de Cambio estado a vencido de la cuenta
   pag_cta.pr_set_variables(user, v_fec_actual, 313, 'N','N', v_nro_secuencia,'V',pag_cta.g_ctas.cod_oficina, pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad );
   If pag_cta.g_ctas.estado != 'B' Then
       pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,
                             'V',
                             v_fec_actual,
                             v_hora,
                             p_nro_cuenta);
   End If;
   v_nro_secuencia           := v_nro_secuencia + 1;
   --- Insertar movimiento de Cambio estado a vencido del certificado
   v_nro_secuencia           := v_nro_secuencia + 1;
   if v_nro_secuencia > 990 then
      v_nro_secuencia := 0;
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
   end if;
   r_gmovi.cod_usuario       := user;
   r_gmovi.hora              := v_hora;
   r_gmovi.nro_secuencia     := v_nro_secuencia;
   r_gmovi.cod_mod_padre     := pag_cta.g_ctas.cod_modulo;
   r_gmovi.cod_mad_padre     := pag_cta.g_ctas.cod_modalidad;
   r_gmovi.cod_oficina       := pag_cta.g_ctas.cod_oficina;
   r_gmovi.cod_modulo        := pag_cta.g_ctas.cod_modulo;
   r_gmovi.cod_modalidad     := pag_cta.g_ctas.cod_modalidad;
   r_gmovi.nro_cuenta        := pag_cta.g_ctas.nro_cuenta;
   r_gmovi.cod_moneda        := pag_cta.g_ctas.cod_moneda;
   r_gmovi.cod_tra_padre     := 313;
   r_gmovi.cod_transaccion   := 403;
   r_gmovi.concepto          := 'Cambio de Estado-Emision Bonos';
   r_gmovi.est_cuenta        := 'V';
   r_gmovi.estado            := 'N';
   r_gmovi.reversado         := 'N';
   r_gmovi.emi_aviso         := 'N';
   r_gmovi.protegido         := 'N';
   r_gmovi.nro_documento     := p_nro_cuenta;
   r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
   r_gmovi.fecha             := v_fec_actual;
   r_gmovi.fec_valor         := v_fec_actual;
   pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');

   if pag_cta.g_ctas.cod_modalidad != 36 then   --RABP-15-01-2015 Se excluye la modalidad 36 de bonos subordinados
       --- Insertar movimiento de traslado contable a Vencido
       v_cod_mon_local           := pag_gen.fu_obt_mon_local;
       v_nro_secuencia           := v_nro_secuencia + 1;
       r_gmovi.cod_usuario       := user;
       r_gmovi.hora              := v_hora;
       r_gmovi.nro_secuencia     := v_nro_secuencia;
       r_gmovi.cod_mod_padre     := pag_cta.g_ctas.cod_modulo;
       r_gmovi.cod_mad_padre     := pag_cta.g_ctas.cod_modalidad;
       r_gmovi.cod_modulo        := pag_cta.g_ctas.cod_modulo;
       r_gmovi.cod_modalidad     := pag_cta.g_ctas.cod_modalidad;
       r_gmovi.cod_oficina       := pag_cta.g_ctas.cod_oficina;
       r_gmovi.nro_cuenta        := pag_cta.g_ctas.nro_cuenta;
       r_gmovi.cod_moneda        := pag_cta.g_ctas.cod_moneda;
       r_gmovi.cod_tra_padre     := 313;
       r_gmovi.cod_transaccion   := 604;
       r_gmovi.concepto          := 'Traslado Contable Capital a Vencido';
       r_gmovi.est_cuenta        := 'V';
       r_gmovi.estado            := 'N';
       r_gmovi.reversado         := 'N';
       r_gmovi.emi_aviso         := 'N';
       r_gmovi.protegido         := 'N';
       r_gmovi.monto             := pag_cta.g_ctas.capital;
       r_gmovi.nro_documento     := p_nro_cuenta;
       r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
       r_gmovi.fecha             := v_fec_actual;
       r_gmovi.fec_valor         := v_fec_actual;
       pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
   end if;
END;

BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;

  -- RABP-CNF 22/01/2015 - Verifica si el movimiento es Nocturno
  If v_est_modulo = 2 then
     v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
  else
     v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
  end if;
  -- RABP-CNF 22/01/2015 - Asigna la Hora Disponible actual
   v_hora  := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno); --'00:00:13'; -- Para que no cree problemas a la hora de reversar. Esto es porque se hace el inicio a la noche...
   v_nro_secuencia := 0;
   for r_cer in c_certificados loop
      --- Recuperar datos de la cuenta en el registro global g_ctas
      pag_cta.pr_obt_cuenta(r_cer.nro_cuenta);
      --- Cambio de estado
      lp_acr_certificado(r_cer.nro_cuenta);
   end loop;
   
   v_hora  := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno); 
   v_nro_secuencia := 0;
   for r_pla in c_pla_vencidos loop
     if v_nro_secuencia > 990 then
        v_nro_secuencia := -999;
     elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
        v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
        v_nro_secuencia := 0 ;
     end if;
     --Debito a la cuenta--       
     pag_cta.pr_act_operacion(r_pla.nro_cuenta,
                              v_hora, --HORA
                              'D',
                              r_pla.cod_moneda,
                              r_pla.sal_total,
                              329,
                              503,
                              r_pla.nro_cuenta,
                              NULL, --COTIZACION
                              r_pla.cod_oficina, --cod_ofi_origen
                              r_pla.cod_modulo, --cod_mod_padre
                              r_pla.cod_modalidad, --cod_mad_padre
                              null, --cod_tasa
                              null, --val_tasa
                              'PAGO PLAZO DIGITAL',
                              'N', --emi_aviso
                              v_nro_secuencia,
                              v_fec_actual);
     if pag_cta.fu_obt_cod_error() <> 0 then
       --Si hubo error
       --BBVASOP-1420
       raise_application_error(-20000,
                               'Act. Pag. Cupón Cta. ' || r_pla.nro_cuenta || '-' ||
                               pag_cta.fu_obt_cod_error() || '-' ||
                               pag_cta.fu_obt_msj_error());
     else
       --Credito a la cuenta--
       pag_cta.pr_act_operacion(r_pla.nro_cta_capitalizacion,
                                v_hora, --HORA
                                'C',
                                r_pla.cod_moneda, --Moneda de la Operación
                                r_pla.sal_total,
                                329,
                                602, --COD_TRA_HIJO (602)
                                r_pla.nro_cuenta,
                                NULL, --COTIZACION
                                r_pla.cod_oficina, --cod_ofi_origen
                                r_pla.cod_modulo, --cod_mod_padre
                                r_pla.cod_modalidad, --cod_mad_padre
                                null, --cod_tasa
                                null, --val_tasa
                                'Pago de plazo digital Cuenta ' || r_pla.nro_cuenta,
                                'S', --emi_aviso
                                v_nro_secuencia,
                                v_fec_actual);
    
       if pag_cta.fu_obt_cod_error() <> 0 then
          --Actualizacion con problemas
          raise_application_error(-20001,
                                  'Act. Pag. Cupón a Cta. ' || r_pla.nro_cuenta || '-' ||
                                  pag_cta.fu_obt_cod_error() || '-' ||
                                  pag_cta.fu_obt_msj_error());
       end if;
     end if;
   end loop;
END;
/

