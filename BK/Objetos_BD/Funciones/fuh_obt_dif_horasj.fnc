CREATE OR REPLACE FUNCTION IT.fuh_obt_dif_horasj
(
   p_hor_desde IN VARCHAR2,
   p_hor_hasta IN VARCHAR2
) RETURN VARCHAR2 IS
   /*modificado por juan jose estigarribia 14/09/2011
    V2 modificado por juan jose estigarribia 10/06/2014*/
   v_diferencia    NUMBER(10, 2) := 0;
   v_tot_seg_desde NUMBER(10, 2);
   v_tot_seg_hasta NUMBER(10, 2);
   v_hora_desde    NUMBER(10, 2);
   v_minuto_desde  NUMBER(10, 2);
   v_segundo_desde NUMBER(10, 2);
   v_hora_hasta    NUMBER(10, 2);
   v_minuto_hasta  NUMBER(10, 2);
   v_segundo_hasta NUMBER(10, 2);
   v_hor_final     NUMBER(5);
   v_min_final     NUMBER(5);
   v_seg_final     NUMBER(5);
   v_dif_final     VARCHAR2(2000);
BEGIN
   --IF p_hor_hasta >= p_hor_desde THEN
   --hora desde 
   v_hora_desde    := to_number(substr(p_hor_desde, 1, 2)) * 3600;
   v_minuto_desde  := to_number(substr(p_hor_desde, 4, 2)) * 60;
   v_segundo_desde := to_number(substr(p_hor_desde, 7, 2));
   v_tot_seg_desde := v_hora_desde + v_minuto_desde + v_segundo_desde;
   --hora hasta
   v_hora_hasta    := to_number(substr(p_hor_hasta, 1, 2)) * 3600;
   v_minuto_hasta  := to_number(substr(p_hor_hasta, 4, 2)) * 60;
   v_segundo_hasta := to_number(substr(p_hor_hasta, 7, 2));
   v_tot_seg_hasta := v_hora_hasta + v_minuto_hasta + v_segundo_hasta;
   -- se restan los segundos
   v_diferencia := v_tot_seg_hasta - v_tot_seg_desde;
   --se optiene el string para luego concatenar
   v_hor_final := trunc(v_diferencia / 3600);
   v_min_final := trunc(MOD(v_diferencia,3600)/60);
   v_seg_final := MOD(MOD(v_diferencia,3600), 60);
   -- se concatena
   v_dif_final := trim(to_char(v_hor_final,'00'))||':'||trim(to_char(v_min_final,'00'))||':'||trim(to_char(v_seg_final,'00'));

   -- ELSE
   -- raise_application_error(-20000, 'Error: Hora Hasta debe ser mayor a Hora Desde');
   --END IF;
   --restorna la hora
   RETURN v_dif_final;
END;
/

