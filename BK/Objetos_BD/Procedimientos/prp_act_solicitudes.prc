create or replace procedure it.PRP_ACT_SOLICITUDES(P_NRO_SOLICITUD IN NUMBER DEFAULT NULL) is
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(6);
  Cursor c1 is
    SELECT nro_solicitud, estado, trunc(fec_modificacion)
      FROM pr_solicitudes
     WHERE estado in ('S','L','Z') -- Solicitado, Pendiente de liquidación
       AND nro_solicitud = nvl(p_nro_solicitud, nro_solicitud)
       AND trunc(fec_modificacion) <=
       pag_cal.fu_obt_fec_actual(6) - nvl(fug_obt_pardinamico('PRE_CAN_DIA_ACT_SOLICITUDES', 6), 30)
       order by 3;

  Cursor c2 is
    SELECT nro_solicitud, estado, trunc(fec_modificacion)
      FROM pr_solicitudes
     WHERE estado in ('C') -- Solicitado, Pendiente de liquidación
       AND nro_solicitud = nvl(p_nro_solicitud, nro_solicitud)
       AND trunc(fec_modificacion) <=
       pag_cal.fu_obt_fec_actual(6) - nvl(fug_obt_pardinamico('PRE_CAN_DIA_SOL_CONDICIONADA', 6),3)
       order by 3;

begin
  For r1 in c1 Loop
    IF nvl(fug_obt_pardinamico('ACT_SOL_EST_NUEVOS'),'N')= 'N' then
      UPDATE pr_solicitudes p
         SET estado = 'D' -- caducado
       WHERE p.nro_solicitud = r1.nro_solicitud;
    ELSE
      --Estado Pendiente de anulación
      IF r1.estado = 'Z' THEN
         UPDATE pr_solicitudes p
            SET estado = 'R' -- rechazado
          WHERE p.nro_solicitud = r1.nro_solicitud;
      END IF;
    END IF;
  End Loop;
  For r2 in c2 loop
          -- Condicionado
       UPDATE pr_solicitudes p
            SET estado = 'Z' --Pendiente de anulación
          WHERE p.nro_solicitud = r2.nro_solicitud;
  end loop;
end PRP_ACT_SOLICITUDES;
/

