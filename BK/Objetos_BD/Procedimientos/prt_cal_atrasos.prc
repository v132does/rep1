CREATE OR REPLACE PROCEDURE IT.PRT_CAL_ATRASOS
 (P_NRO_CUENTA IN VARCHAR2 DEFAULT NULL
 )
 IS
  CURSOR c1
      IS select t.nro_cuenta, t.dia_mora,
                decode( nvl( t.dia_mora, 0 ), 0, 'N', 'S' ) mar_mora, t.rowid registro
           from ta_cta_tarjetas t, ge_est_cuentas e
          where t.nro_cuenta = nvl( p_nro_cuenta, nro_cuenta )
            and t.cod_modulo = e.cod_modulo
            and t.cod_modalidad = e.cod_modalidad
            and t.estado = e.estado
            and nvl( e.activo, 'N' ) = 'S';
   --JG 16/02/2011. Se comenta del cursor el campo mto_mora,
   --ya que ta_cta_tarjetas ya tiene dichos datos actualizados
   --desde ta_cta_tarjetas_tmp. Mirar AP 1581
  v_max_atraso  TA_CTA_TARJETAS.MAX_ATRASO%TYPE := 0;
  v_pro_atraso  TA_CTA_TARJETAS.PRO_ATRASO%TYPE := 0;
  v_mto_mora    TA_CTA_TARJETAS.MTO_MORA%TYPE := 0;
  v_dia_atraso  TA_CTA_TARJETAS.DIA_MORA%TYPE := 0;
  v_mar_mora    TA_CTA_TARJETAS.MAR_MORA%TYPE := 'N';
  r_cal         GE_CALENDARIOS%ROWTYPE;
BEGIN
  FOR r1 IN c1 LOOP
    v_max_atraso := 0;
    v_pro_atraso := 0;
/*
    BEGIN
      select max( nvl( dia_atraso, 0 ) ), avg( nvl( dia_atraso, 0 ) )
        into v_max_atraso, v_pro_atraso
        from ta_sal_cierres
       where nro_cuenta = r1.nro_cuenta;
    EXCEPTION
      when others then
        v_max_atraso := NULL;
        v_pro_atraso := NULL;
    END;
*/
    v_dia_atraso := nvl( r1.dia_mora, 0 );
    v_mar_mora := r1.mar_mora;
    r_cal := pag_cal.fu_obt_reg_cal(5);
    IF r_cal.fec_actual = r_cal.ult_dia_mes_habil THEN
      IF nvl( v_dia_atraso, 0 ) > 0 THEN
        v_dia_atraso := nvl( v_dia_atraso, 0 ) + ( r_cal.ult_dia_mes - r_cal.ult_dia_mes_habil );
      END IF;
    END IF;
    if v_max_atraso < v_dia_atraso then
       v_max_atraso := v_dia_atraso;
    end if;
    BEGIN
      update ta_cta_tarjetas
         set max_atraso = v_max_atraso,
             dia_mora   = v_dia_atraso,
             mar_mora   = v_mar_mora
       where nro_cuenta = r1.nro_cuenta;
    EXCEPTION
      when others then
        RAISE_APPLICATION_ERROR( -20055, 'No se pudo actualizar el estado de la tarjeta ' || r1.nro_cuenta || '; ' || sqlerrm );
    END;
  END LOOP;
END prt_cal_atrasos;
/

