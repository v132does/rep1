create or replace package body it.PAV_VEN is
/* Realizar asientos contables por el cambio de estado de la operación vencida. */
PROCEDURE PR_INS_ASIENTO( p_cod_tra_padre   IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
                          p_cod_transaccion IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                          p_monto           IN GE_MOVIMIENTOS.MONTO%TYPE,
                          p_concepto        IN GE_MOVIMIENTOS.CONCEPTO%TYPE,
                          p_estado          IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
                          ) IS
  r_mvto GE_MOVIMIENTOS%ROWTYPE;
BEGIN
  r_log.nom_proceso := 'PAV_VEN.PR_INS_ASIENTO';
  r_log.fec_hor_ini := sysdate;
  IF nvl( g_secuencia, 0 ) + 3 > 999 THEN
    g_secuencia := 0;
    g_hor_movim := pag_gen.fu_obt_sig_segundo( g_hor_movim );
  ELSE
    g_secuencia := nvl( g_secuencia, 0 ) + 1;
  END IF;
  r_mvto.nro_secuencia   := nvl( g_secuencia, 0 );
  r_mvto.cod_usuario     := substr( upper( user ), 1, 10 );
  r_mvto.hora            := g_hor_movim;
  r_mvto.cod_modulo      := g_cod_modulo;   --definir hijo
  r_mvto.cod_modalidad   := g_cod_modalidad;  --definir hijo
  r_mvto.cod_oficina     := g_cod_oficina;
  r_mvto.nro_cuenta      := g_nro_cuenta;
  r_mvto.cod_moneda      := g_cod_moneda;
  r_mvto.cod_tra_padre   := p_cod_tra_padre;
  r_mvto.cod_transaccion := p_cod_transaccion;
  r_mvto.fecha           := c_fec_actual;
  r_mvto.fec_valor       := c_fec_actual;
  r_mvto.nro_documento   := NULL;
  r_mvto.monto           := p_monto;
  r_mvto.estado          := 'N';
  r_mvto.est_cuenta      := p_estado;
  r_mvto.cod_ofi_origen  := g_cod_oficina;
  r_mvto.concepto        := p_concepto;
  r_mvto.reversado       := 'N';
  r_mvto.emi_aviso       := 'N';
  r_mvto.protegido       := 'N';
  r_mvto.cod_mod_padre   := g_cod_modulo;
  r_mvto.cod_mad_padre   := g_cod_modalidad;
  IF g_cod_moneda = c_mon_local THEN
    r_mvto.mto_equ_local := NULL;
    r_mvto.cotizacion    := NULL;
  ELSE
    r_mvto.mto_equ_local := round( p_monto * g_cotizacion, 0 );
    r_mvto.cotizacion    := g_cotizacion;
  END IF;
  pag_gen.pr_ins_ge_movimiento( r_mvto ); --OJO
EXCEPTION
  WHEN others THEN
    IF sqlcode <= -20000 THEN
      raise;
    ELSE
      RAISE_APPLICATION_ERROR( -20302, sqlerrm || ' Al insertar mvto. Cambio Situación Operación Vencida ' || g_nro_cuenta );
    END IF;
END PR_INS_ASIENTO;
/* Recupera monto previsión de ge_cla_operaciones. */
FUNCTION FU_OBT_PREVISION( p_nro_cuenta IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE ) RETURN NUMBER IS
  v_prevision GE_CLA_OPERACIONES.TOT_PREVISION%TYPE;
BEGIN
  select sum( nvl( monto, 0 ) )
    into v_prevision
    from ov_previsiones
   where nro_cuenta = p_nro_cuenta
     and fecha = ( select max( fecha )
                     from ov_previsiones
                    where nro_cuenta = p_nro_cuenta
                      and fecha <= pav_ven.c_fec_actual );
  return nvl( v_prevision, 0 );
EXCEPTION
  when others then
    IF sqlcode <= -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR( -20000, 'Recup. Previsión - Cta: ' || p_nro_cuenta );
    END IF;
END FU_OBT_PREVISION;

END PAV_VEN;
/

