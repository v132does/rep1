CREATE OR REPLACE PROCEDURE IT."PRC_CAM_ESTADOS"
IS

-- Cuentas Corrientes que cambian de situacion.
cursor c_cta_corrientes is
 select cc.cod_modulo, cc.cod_modalidad, cc.cod_oficina, cc.nro_cuenta,
        cc.estado, cc.fec_cam_estado,
        fup_obt_categoria(cli.cat_automatica,cli.cat_subjetiva) categoria,
        nvl(f.dias_sobregiro,0) dias_sobregiro, nvl(f.sit_deuda,cc.estado) sit_deuda
   from ge_clientes cli, ge_cta_clientes ccl, cc_cta_corrientes cc,
        (select can_dias dias_sobregiro, d.nro_Cuenta, d.sit_deuda
           from CC_SOBREGIROS_RES D) f
  where cc.nro_cuenta = ccl.nro_cuenta
    and ccl.cod_persona = cli.cod_persona
    and ccl.relacion = 'P'
    and cc.estado not in('C','I')
    and (nvl(cc.sal_total,0)-nvl(cc.sal_bloqueado,0)-nvl(cc.sal_retenido,0)) < 0     
    and f.nro_cuenta(+) = cc.nro_cuenta  
 order by cc.nro_cuenta;
 
--Variables.
 v_fec_inicio     ge_calendarios.fec_actual%type;
 v_fec_anterior   ge_calendarios.fec_anterior%type; -- CN 05/2014
 v_hora           ge_movimientos.hora%type;
 v_nro_secuencia  ge_movimientos.nro_secuencia%type;

    ------Determinacion de Situacion de sobregiro--------
    FUNCTION fu_obt_est_sobregiro (
        p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE
    ) RETURN VARCHAR2 AS

        v_can_dias cc_sobregiros.can_dia_sobregiro%TYPE;
        v_fec_ant DATE;
        --v_fec_inicio DATE; --Siempre establece v_fec_ant = null -- CN 05/2014

        -- Obtiene la cantidad de días hasta la ante última fecha
        CURSOR sg IS
            SELECT nro_cuenta, fecha, saldo, mto_linea
                FROM cv_cta_sobregiros
                --WHERE fecha < v_fec_inicio -- CN 05/2014 : Debido a que el cambio de estado según los dias en sobregiro se puede dar un fin de semana o feriado y esto se actualiza solo en el cierre del siguiente dia hábil.
                WHERE fecha <= v_fec_anterior
                AND nro_cuenta = p_nro_cuenta
                ORDER BY 2 DESC, 3 ASC;
        
               
        FUNCTION fu_obt_situacion (
            p_can_dias IN cc_sobregiros.can_dias%TYPE
        ) RETURN cc_sobregiros_res.sit_deuda%TYPE IS
            v_sitsal cc_sobregiros_res.sit_deuda%TYPE;
        BEGIN
          IF NVL(p_can_dias, 0) < 61 THEN
              v_sitsal := 'N';   -- Normal 
          ELSIF p_can_dias < 91 THEN
              v_sitsal := 'V';   -- Vencido
          ELSIF p_can_dias < 181 THEN
              v_sitsal := 'G';   -- Gestión
          ELSIF p_can_dias < 361 THEN
              v_sitsal := 'M';   -- Moroso
          ELSE
              v_sitsal := 'I';   -- Incobrable
          END IF;         
            RETURN v_sitsal;
        END fu_obt_situacion;
    BEGIN
        --v_fec_ant := v_fec_inicio; -- CN 05/2014 : Debido a que el cambio de estado según los dias en sobregiro se puede dar un fin de semana o feriado y esto se actualiza solo en el cierre del siguiente dia hábil.
        v_fec_ant := v_fec_anterior;
        v_can_dias := 0;   
                
        FOR c IN sg LOOP
            IF (v_fec_ant - c.fecha) > 1 
            --OR (c.mto_linea <= c.saldo) THEN  
            OR (c.mto_linea >= c.saldo) THEN -- CN 05/2014 : Si el monto de la linea es mayor al saldo no debe sumar los días --
                EXIT;
            END IF;
            v_fec_ant := c.fecha;        
            v_can_dias := v_can_dias + 1;
        END LOOP;  
             
        RETURN fu_obt_situacion(v_can_dias);        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';  -- estado normal               
        WHEN OTHERS THEN
            RETURN null;
    END fu_obt_est_sobregiro;
BEGIN
  
   -- Obtener fecha calendario
   pag_cal.PR_OBT_DAT_CALENDAR(4);
   v_fec_inicio    := pag_cal.g_fec_actual;
   v_fec_anterior  := pag_cal.g_fec_anterior; --CN 05/2014 : Debido a que el cambio de estado según los dias en sobregiro se puede dar un fin de semana o feriado y esto se actualiza solo en el cierre del siguiente dia hábil.
   --v_hora          := fug_ini_hora(sysdate,'HH24:MI:SS');
   --FQ Para evitar error de PK
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fec_inicio,v_hora,user,'N'); 
   v_nro_secuencia := 0;
  
   for reg in c_cta_corrientes loop
      -- Procesando Sobregiros que cambian de estado.
      if v_nro_secuencia + 10 > 998 then
         --- Reiniciar secuencia y hora
         v_nro_secuencia := 0;
         --v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         --FQ Para evitar error de PK
         v_hora := fug_obt_hor_disponible(v_fec_inicio,v_hora,user,'N');
      end if;
      pac_mes.pr_cam_situacion (reg.cod_modulo,
                                reg.cod_modalidad,
                                reg.cod_oficina,
                                reg.nro_cuenta,
                                reg.categoria,
                                v_fec_inicio,
                                --reg.sit_deuda,
                                fu_obt_est_sobregiro(reg.nro_cuenta), -- situación de la deuda                                
                                v_hora,
                                v_nro_secuencia);
   end loop;
END;
/

