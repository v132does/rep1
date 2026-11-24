CREATE OR REPLACE PROCEDURE IT.PRA_CRE_AUT_CUP_PLA_VENCIDO
IS
  --Variables Locales--
  v_fec_actual    ge_calendarios.fec_actual%type;
  v_hora          ge_movimientos.hora%type := TO_CHAR(SYSDATE,'HH24:MI:SS');
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_est_modulo    ba_modulos.estado%type := pae_cnf.FU_OBT_EST_MODULO(3);
  v_horario       varchar2(1) := 'D'; -- Dia normal DYDMR-5039 OMM. Sep/2016
  v_es_nocturno   varchar2(1) := 'N';

  --Curosr de cupones plazo Digital
  cursor c_cup_plazo is
    select CU.NRO_CUENTA,
           CD.COD_MODULO,
           CD.COD_MODALIDAD,
           CU.NRO_CUPON,
           NVL(MTO_INTERES, 0) MTO_INTERES,
           CU.FEC_VENCIMIENTO,
           CD.NRO_CTA_CAPITALIZACION,
           CD.COD_MONEDA,
           CD.COD_OFICINA,
           CU.ROWID linea
      from AH_CUPONES CU, AH_CTA_PLAZOS CD
     where CD.NRO_CUENTA = CU.NRO_CUENTA
       AND CD.ESTADO NOT IN ('A', 'T', 'C')
       AND CU.ESTADO = 'V'
       AND CD.COD_MODALIDAD = 37
       AND NVL(CU.BLOQUEADO, 'N') = 'N'
       --AND CD.CRE_AUTOMATICO = 'S'
       AND CD.NRO_CTA_CAPITALIZACION IS NOT NULL
       and CU.FEC_VENCIMIENTO <= v_fec_actual;

BEGIN
  v_fec_actual    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

  -- OMM 22/12/2014 - Verifica si el movimiento es Nocturno
  If v_est_modulo = 2 then
     v_es_nocturno := 'N'; -- N=Abierto, S=Cerrado
     v_horario := 'D' ;    -- D=Abierto, N=Cerrado
  else
     v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
     v_horario := 'N' ;    -- D=Abierto, N=Cerrado
  end if;
  -- OMM 22/12/2014 - Asigna la Hora Disponible actual
  v_hora  := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno); --'00:00:13'; -- Para que no cree problemas a la hora de reversar. Esto es porque se hace el inicio a la noche...
  -- Actualiza el horario del pag_cta según estado del modulo DYDMR-5039 OMM. Sep/2016
  pag_cta.g_horario := v_horario;

  for r_cup in c_cup_plazo loop
     -- OMM 22/12/2014 - Valida para usar la secuencia negativa o de lo contrario aumenta en un segundo
     if v_nro_secuencia > 990 then
        v_nro_secuencia := -999;
     elsif v_nro_secuencia < 0 and v_nro_secuencia > -10 then
        v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,v_es_nocturno);
        v_nro_secuencia := 0 ;
     end if;

    --Debito a la cuenta--
    pag_cta.pr_act_operacion(r_cup.nro_cuenta,
                             v_hora, --HORA
                             'D',
                             r_cup.cod_moneda,
                             r_cup.mto_interes,
                             311,
                             547,
                             r_cup.nro_cupon,
                             NULL, --COTIZACION
                             r_cup.cod_oficina, --cod_ofi_origen
                             r_cup.cod_modulo, --cod_mod_padre
                             r_cup.cod_modalidad, --cod_mad_padre
                             null, --cod_tasa
                             null, --val_tasa
                             'PAGO DE CUPON',
                             'N', --emi_aviso
                             v_nro_secuencia,
                             v_fec_actual);
    if pag_cta.fu_obt_cod_error() <> 0 then
      --Si hubo error
      --BBVASOP-1420
      raise_application_error(-20000,
                              'Act. Pag. Cupón Cta. ' || r_cup.nro_cuenta || '-' ||
                              pag_cta.fu_obt_cod_error() || '-' ||
                              pag_cta.fu_obt_msj_error());
    else
      --Credito a la cuenta--
      pag_cta.pr_act_operacion(r_cup.nro_cta_capitalizacion,
                               v_hora, --HORA
                               'C',
                               r_cup.cod_moneda, --Moneda de la Operación
                               r_cup.mto_interes,
                               311,
                               602, --COD_TRA_HIJO (602)
                               r_cup.nro_cupon,
                               NULL, --COTIZACION
                               r_cup.cod_oficina, --cod_ofi_origen
                               r_cup.cod_modulo, --cod_mod_padre
                               r_cup.cod_modalidad, --cod_mad_padre
                               null, --cod_tasa
                               null, --val_tasa
                               'Pago de cupon Cuenta ' || r_cup.nro_cuenta,
                               'S', --emi_aviso
                               v_nro_secuencia,
                               v_fec_actual);

      if pag_cta.fu_obt_cod_error() <> 0 then
        --Actualizacion con problemas
        raise_application_error(-20001,
                                'Act. Pag. Cupón a Cta. ' || r_cup.nro_cuenta || '-' ||
                                pag_cta.fu_obt_cod_error() || '-' ||
                                pag_cta.fu_obt_msj_error());
      end if;

      --Actualizar Cupones Pagados--
      begin
        update AH_CUPONES
           set ESTADO = 'P', FEC_PAGO = v_fec_actual
         where rowid = r_cup.linea;
      exception
        when others then
          raise_application_error(-20002, 'Act.Cupón a Pagado ' || sqlerrm);
      end;
    end if;
  end loop;
END;
/

