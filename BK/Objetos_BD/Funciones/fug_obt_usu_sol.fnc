CREATE OR REPLACE FUNCTION IT.FUG_OBT_USU_SOL
 (P_COD_ESTADO IN GE_SOLICITUDES.COD_ESTADO%TYPE
 ,P_COD_MODULO IN GE_SOLICITUDES.COD_MODULO%TYPE
 ,P_COD_CAMPANA IN GE_SOLICITUDES.COD_CAMPANA%TYPE
 ,P_COD_CANAL IN GE_SOLICITUDES.COD_CANAL%TYPE
 ,P_COD_MONEDA IN GE_SOLICITUDES.COD_MONEDA%TYPE
 ,P_MONTO IN GE_SOLICITUDES.MONTO%TYPE
 ,P_COD_USUARIO IN VARCHAR2 := 'NULL'
 )
 RETURN VARCHAR2
 IS

/* Obtener cantidad de solicitudes asignandas al usuario en un estado. */
FUNCTION LF_OBT_CAN_SOLICITUD
 (P_COD_ESTADO IN GE_SOL_DISTRIBUCIONES.COD_ESTADO%TYPE
 ,P_COD_USUARIO IN GE_SOL_DISTRIBUCIONES.COD_USUARIO%TYPE
 )
 RETURN NUMBER;
/* Recuperar tipo de canal. */
FUNCTION LF_OBT_TIP_CANAL
 (P_COD_CANAL IN GE_CANALES.COD_TIP_CANAL%TYPE
 )
 RETURN NUMBER;
--- Variables auxiliares
   v_cod_usuario ba_usuarios.cod_usuario%type;
   v_can_menor   number(5);
   v_cantidad    number(5);
   v_cod_tip_canal ge_canales.cod_tip_canal%type;

   --- Cursor de usuarios a distribuir
   CURSOR c_usu_distribucion IS
   select d.cod_usuario
     from ge_sol_rangos r, ge_sol_distribuciones d
    where d.cod_rango = r.cod_rango
      and cod_estado  = p_cod_estado
      and p_monto between r.mto_inicial and r.mto_final
      and r.cod_moneda = p_cod_moneda
      and d.cod_usuario != nvl(p_cod_usuario,'x')
      and (nvl(cod_campana, -1) = p_cod_campana OR
              (COD_CAMPANA IS NULL AND NOT EXISTS
                       (SELECT '1'
                          FROM GE_SOL_RANGOS XR, GE_SOL_DISTRIBUCIONES X
                         WHERE X.COD_RANGO = XR.COD_RANGO
                           and p_monto between XR.mto_inicial and XR.mto_final
                           and xr.cod_moneda = p_cod_moneda
                           and x.cod_estado  = p_cod_estado
                           AND X.COD_CAMPANA = p_cod_campana)))
      and (nvl(cod_modulo, p_cod_modulo) = p_cod_modulo)
      and (nvl(cod_canal, -1)  = p_cod_canal OR
              (COD_CANAL IS NULL AND NOT EXISTS
                        (SELECT '1'
                           FROM GE_SOL_RANGOS XR, GE_SOL_DISTRIBUCIONES X
                          WHERE X.COD_RANGO = XR.COD_RANGO
                            and p_monto between XR.mto_inicial and XR.mto_final
                            and xr.cod_moneda = p_cod_moneda
                            and x.cod_estado  = p_cod_estado
---------------
                            AND (NVL(x.cod_campana,-1) = p_cod_campana or
                              (COD_CAMPANA IS NULL AND NOT EXISTS
                                       (SELECT '1'
                                          FROM GE_SOL_RANGOS XR, GE_SOL_DISTRIBUCIONES X
                                         WHERE X.COD_RANGO = XR.COD_RANGO
                                           and p_monto between XR.mto_inicial and XR.mto_final
                                           and xr.cod_moneda = p_cod_moneda
                                           and x.cod_estado  = p_cod_estado
                                           AND X.COD_CAMPANA = p_cod_campana)))
---------------
                            AND X.COD_CANAL = p_cod_canal)))
      and (nvl(cod_tip_canal, -1) = v_cod_tip_canal OR
              (COD_TIP_CANAL IS NULL AND NOT EXISTS
                        (SELECT '1'
                           FROM GE_SOL_RANGOS XR, GE_SOL_DISTRIBUCIONES X
                          WHERE X.COD_RANGO = XR.COD_RANGO
                            and p_monto between XR.mto_inicial and XR.mto_final
                            and xr.cod_moneda = p_cod_moneda
                            and x.cod_estado  = p_cod_estado
                            AND X.COD_TIP_CANAL = v_cod_tip_canal)));

/* Obtener cantidad de solicitudes asignandas al usuario en un estado. */
FUNCTION LF_OBT_CAN_SOLICITUD
 (P_COD_ESTADO IN GE_SOL_DISTRIBUCIONES.COD_ESTADO%TYPE
 ,P_COD_USUARIO IN GE_SOL_DISTRIBUCIONES.COD_USUARIO%TYPE
 )
 RETURN NUMBER
 IS
v_cantidad number(5);
BEGIN
   select nvl(count(*),0)
     into v_cantidad
     from ge_sol_gestiones g
    where g.cod_estado  = p_cod_estado
      and g.cod_usuario = p_cod_usuario
--   Esto es para asignar en forma equitativa de todo lo que posee...
      and g.fecha =
         (select max(gf.fecha)
            from ge_sol_gestiones gf
           where gf.nro_solicitud = g.nro_solicitud);
   return v_cantidad;
END;
/* Recuperar tipo de canal. */
FUNCTION LF_OBT_TIP_CANAL
 (P_COD_CANAL IN GE_CANALES.COD_TIP_CANAL%TYPE
 )
 RETURN NUMBER
 IS
v_cod_tip_canal ge_canales.cod_tip_canal%type;
BEGIN
   select cod_tip_canal
     into v_cod_tip_canal
     from ge_canales
    where cod_canal = p_cod_canal;
   return v_cod_tip_canal;
exception
   when others then
      raise_application_error(-20000,
      'Rec.Canal '||sqlerrm);
END;
BEGIN
   v_can_menor     := 99999;
   v_cantidad      := 0;
   v_cod_usuario   := null;
   v_cod_tip_canal := null;
   --- Recuperar tipo de canal
   IF p_cod_canal is not null then
      v_cod_tip_canal := lf_obt_tip_canal(p_cod_canal);
   end if;
   if p_cod_estado in ('PVT','PAN') and fug_obt_tip_implementacion = 2 then
      v_cod_usuario := user;
   else
      for c_dis in c_usu_distribucion loop
         -- Recuperar la cantidad de solicitudes que posee el usuario en esa campaña
         v_cantidad := lf_obt_can_solicitud(p_cod_estado, c_dis.cod_usuario);
         if v_cantidad  < v_can_menor then
            v_can_menor   := v_cantidad;
            v_cod_usuario := c_dis.cod_usuario;
         end if;
      end loop;
   end if;
   if v_cod_usuario is null then
      raise_application_error(-20000,
      'Distribucion no registrada para: Estado '||p_cod_estado||
      ' Campaña '||p_cod_campana||' Canal '||p_cod_canal||' Producto '||p_cod_modulo||
      ' Monto '||p_cod_moneda||' '||p_monto);
   end if;
   return v_cod_usuario;
END;
/

