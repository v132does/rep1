CREATE OR REPLACE PROCEDURE IT.prc_act_res_sobregiros IS

  v_fec_max_sobregiro date;
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_can_dias number;
  v_can_dia_sobregiro cc_sobregiros.can_dia_sobregiro%TYPE;
  
  cursor c_sobregiros_res is
    select x.*
      from cc_sobregiros_res x;

   -- inserta registro en sobregiros res en caso de no existir
   PROCEDURE lp_ins_cc_sobregiros_res IS
      v_fcanter        date;
      v_fcdehoy        date;
      v_can_dia_exceso   cc_sobregiros.can_dias%TYPE;
      v_can_dia_sobregiro cc_sobregiros.can_dia_sobregiro%TYPE;
      v_mto_linea cc_sobregiros.mto_linea%type;
      v_sit_deuda cc_sobregiros_res.sit_deuda%type;
      v_mto_mora  cc_sobregiros_res.mto_mora%type;
      v_fcproxi        date;
      v_dias           number;
      CURSOR cuentas IS
       SELECT  a.nro_cuenta,
               abs(nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) - nvl(a.sal_bloqueado, 0)) saldo,
               decode(nvl(c.nro_cuenta, 'x'), 'x', 'N', 'S') CTRL_SOB --muestra si debe considerarse sobregiro los dias no habiles si = N no inserta
          FROM cc_cta_corrientes a, cc_sobregiros_res b,(select distinct nro_cuenta 
                                                           from cc_sobregiros
                                                          where can_dias is null
                                                            and fecha > v_fcanter) c  -- entra en sobregiro por cobro de sobregiros no teniendo saldo
        WHERE a.nro_cuenta = b.nro_cuenta(+) -- ya tiene registro de resumen cc_sobregiros_res
          AND c.nro_cuenta(+) = a.nro_cuenta
          AND a.cod_modalidad = 41
          AND a.estado <> 'C'
          AND nvl(a.sal_total, 0) - nvl(a.sal_retenido, 0) -
               nvl(a.sal_bloqueado, 0) < 0
          AND b.nro_cuenta IS NULL; -- ctas que no tienen registro cc_sobregiro_res, entraron en sobregiro luego del ultimo calculo de sobregiro  
    BEGIN
      pag_cal.pr_obt_dat_calendar(4);
      v_fcdehoy := pag_cal.g_fec_actual;
      v_fcanter := pag_cal.g_fec_anterior;
      
      IF v_fcanter+1 <> v_fcdehoy  AND TO_CHAR(v_fcanter,'MM') <> TO_CHAR(v_fcdehoy ,'MM') THEN
        --- voy a actualizar los saldos desde 1 del mes sgte. -----
        v_dias := (TO_NUMBER(TO_CHAR(v_fcdehoy,'DD'))) -1;
        v_can_dia_sobregiro := v_dias;
          
        FOR j IN cuentas LOOP
          if j.ctrl_sob = 'S' then
            v_mto_linea := nvl(pag_cta.fu_obt_lin_sobregiro(j.nro_cuenta, v_fcdehoy),0);   
                   
            if v_mto_linea >= j.saldo then
              v_can_dia_exceso := 0;
              v_sit_deuda := 'S';
              v_mto_mora := 0;
            else
              v_can_dia_exceso := v_can_dia_sobregiro;
              v_sit_deuda := 'M';
              v_mto_mora := v_mto_linea - j.saldo;
            end if;
          
            --  inserto los datos en el cc_sobregiros_res
            /*INSERT INTO cc_sobregiros_res
              (nro_cuenta, can_dias, sit_deuda, can_dia_sobregiro, mto_mora)
            VALUES
              (j.nro_cuenta,
               nvl(v_can_dia_exceso, 0),
               v_sit_deuda,
               nvl(v_can_dia_sobregiro, 0),
               v_mto_mora);*/ -- DYDMR-6132 NAF 03/2017
          end if;
        END LOOP;
    END IF;
  END;

   -- DYDMR-6132 NAF 03/2017 actualiza con cero registros de sobregiros con cant_dias null
   PROCEDURE lp_upd_cc_sobregiros IS
      v_fcanter        date;
      v_fcdehoy        date;
       
    BEGIN
      pag_cal.pr_obt_dat_calendar(4);
      v_fcdehoy := pag_cal.g_fec_actual;
      v_fcanter := pag_cal.g_fec_anterior;
      
      update CC_SOBREGIROS t
             set can_dias = 0, 
                 can_dia_sobregiro = 0
      where can_dias IS NULL 
         and can_dia_sobregiro IS NULL
         and t.fecha between v_fcanter and v_fcdehoy;

    END;
  
begin
  -- lp_ins_cc_sobregiros_res; -- DYDMR-6132 NAF 03/2017
  lp_upd_cc_sobregiros; 
  
  for cta in c_sobregiros_res loop
      --Traer la fecha de maximo sobregiro--
      select max(k.fecha)
        into v_fec_max_sobregiro
        from cc_sobregiros k
       where k.nro_cuenta = cta.nro_cuenta;
      
      v_can_dias := 0;
      v_can_dias := v_fec_actual - v_fec_max_sobregiro;
      
      --Actualizar si faltan dias--
      if v_can_dias > 1 then
         update cc_sobregiros_res t
            set t.can_dia_sobregiro = nvl(t.can_dia_sobregiro,0) + (nvl(v_can_dias,0) - 1),
                t.can_dias = nvl(t.can_dias,0) + (nvl(v_can_dias,0) - 1)
          where t.nro_cuenta = cta.nro_cuenta;
      end if;
  end loop;
exception
  when others then
       RAISE_APPLICATION_ERROR(-20830, 'ERROR. en prc_act_res_sobregiros: ' ||sqlerrm);
end;
/

