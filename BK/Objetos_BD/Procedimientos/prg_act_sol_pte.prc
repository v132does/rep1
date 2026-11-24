CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SOL_PTE
 IS

  V_NRO_SOLICITUD GE_SOLICITUDES.NRO_SOLICITUD%type;
  V_COD_ESTADO    GE_SOLICITUDES.COD_ESTADO%type;
  V_COD_USUARIO   GE_SOL_GESTIONES.COD_USUARIO%type;
  v_can_dia_ent   number(5) := 0;
  v_can_dia_ven   number(5) := 0;
  r_gsges ge_sol_gestiones%rowtype;
-- recupera solicitudes de prestamos
CURSOR C_SOL_PRES IS
SELECT NRO_SOLICITUD,
       COD_ESTADO
  FROM GE_SOLICITUDES
 WHERE round(trunc(sysdate)-trunc(FEC_CAM_ESTADO)) > v_can_dia_ent
       AND COD_MODULO = 6
       AND COD_ESTADO = 'APR'
   FOR UPDATE OF COD_ESTADO;
-- recupera solicitudes de tarjetas
CURSOR C_SOL_TARJ IS
SELECT NRO_SOLICITUD,
       COD_ESTADO
  FROM GE_SOLICITUDES
 WHERE round(trunc(sysdate)-trunc(FEC_CAM_ESTADO)) > v_can_dia_ent
       AND COD_MODULO = 5
       AND COD_ESTADO = 'APR'
   FOR UPDATE OF COD_ESTADO;

--recupera solicitudes condicionadas con dias transcurridos mayor a parametro--
CURSOR C_SOL_COND IS
select a.nro_solicitud, a.cod_estado, a.cod_usuario
  from ge_sol_gestiones a
 where a.cod_estado = 'PVC' --condicionadas--
   and a.tipo = 'E' --externas--
   and round(trunc(sysdate)-trunc(a.fecha)) > v_can_dia_ven
   and exists (select 1
                 from ge_solicitudes b
                where b.nro_solicitud = a.nro_solicitud
                  and b.cod_estado = a.cod_estado
                  and b.tipo = a.tipo)
   and a.fecha = (select max(x.fecha)
                    from ge_sol_gestiones x
                   where x.nro_solicitud = a.nro_solicitud
                     and x.cod_estado = a.cod_estado);

BEGIN
--    proceso de solicitudes de prestamos
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
      v_can_dia_ent := FUG_OBT_PARDINAMICO('CAN_DIA_ENT_SOL',6,NULL,NULL,NULL);
      IF C_SOL_PRES%ISOPEN THEN
         CLOSE C_SOL_PRES;
      END IF;
      OPEN C_SOL_PRES;
      LOOP
         FETCH C_SOL_PRES INTO V_NRO_SOLICITUD,V_COD_ESTADO;
         EXIT WHEN C_SOL_PRES%NOTFOUND;

         UPDATE GE_SOLICITUDES
         SET COD_ESTADO = 'NEN'
         WHERE CURRENT OF C_SOL_PRES;
         -- Inserta la Gestión
         r_gsges.cod_usuario := user;
         r_gsges.nro_solicitud := v_nro_solicitud;
         r_gsges.cod_estado    := 'NEN';
         r_gsges.observacion   := 'Sobrepaso los '||v_can_dia_ent||' días.';
         prg_ins_ge_sol_gesti(r_gsges);
         --
      END LOOP;
      CLOSE C_SOL_PRES;
      -- Proceso de solicitudes de tarjetas
      v_can_dia_ent := FUG_OBT_PARDINAMICO('CAN_DIA_ENT_SOL',5,NULL,NULL,NULL);
      IF C_SOL_TARJ%ISOPEN THEN
         CLOSE C_SOL_TARJ;
      END IF;
      OPEN C_SOL_TARJ;
      LOOP
         FETCH C_SOL_TARJ INTO V_NRO_SOLICITUD,V_COD_ESTADO;
         EXIT WHEN C_SOL_TARJ%NOTFOUND;

         UPDATE GE_SOLICITUDES
         SET COD_ESTADO = 'NEN'
         WHERE CURRENT OF C_SOL_TARJ;
         -- Inserta la Gestión
         r_gsges.cod_usuario := user;
         r_gsges.nro_solicitud := v_nro_solicitud;
         r_gsges.cod_estado    := 'NEN';
         r_gsges.observacion   := 'Sobrepaso los '||v_can_dia_ent||' días.';
         prg_ins_ge_sol_gesti(r_gsges);
         --
      END LOOP;
      CLOSE C_SOL_TARJ;

      --Proceso de Condicionadas a Anuladas--
      v_can_dia_ven := FUG_OBT_PARDINAMICO('CAN_DIA_VEN_CON',NULL,NULL,NULL,NULL);
      IF C_SOL_COND%ISOPEN THEN
         CLOSE C_SOL_COND;
      END IF;
      OPEN C_SOL_COND;
      LOOP
         FETCH C_SOL_COND INTO V_NRO_SOLICITUD,V_COD_ESTADO,V_COD_USUARIO;
         EXIT WHEN C_SOL_COND%NOTFOUND;

         UPDATE GE_SOLICITUDES N
         SET N.COD_ESTADO = 'ANU',
             N.TIPO = null
         WHERE N.NRO_SOLICITUD = V_NRO_SOLICITUD;
         -- Inserta la Gestión
         r_gsges.cod_usuario := v_cod_usuario;
         r_gsges.nro_solicitud := v_nro_solicitud;
         r_gsges.cod_estado    := 'ANU';
         r_gsges.observacion   := 'Sobrepaso los '||v_can_dia_ven||' días.';
         prg_ins_ge_sol_gesti(r_gsges);
         --
      END LOOP;
      CLOSE C_SOL_COND;
END;
/

