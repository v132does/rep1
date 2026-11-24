CREATE OR REPLACE TRIGGER IT.TA_AP_REQ_APROBACIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON AP_REQ_APROBACIONES
 FOR EACH ROW


DECLARE

/* Verificar si se completo el circuito. */
FUNCTION LF_VER_NIVELCIRCUITO
 (P_COD_GRUPO IN AP_GRU_TIP_REQ.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_GRU_TIP_REQ.COD_TIP_REQUERIMIENTO%TYPE
 ,P_ORDEN IN AP_GRU_TIP_REQ.ORDEN%TYPE
 )
 RETURN INTEGER;

/* Verificar si se completo el circuito. */
FUNCTION LF_VER_NIVELCIRCUITO
 (P_COD_GRUPO IN AP_GRU_TIP_REQ.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_GRU_TIP_REQ.COD_TIP_REQUERIMIENTO%TYPE
 ,P_ORDEN IN AP_GRU_TIP_REQ.ORDEN%TYPE
 )
 RETURN INTEGER
 IS

V_ORDEN AP_GRU_TIP_REQ.ORDEN%TYPE;
BEGIN
   select max(orden)
   into v_orden
   from ap_gru_tip_req
   where cod_grupo = p_cod_grupo
   and cod_tip_requerimiento = p_cod_tip_requerimiento;
   dbms_output.put_line('orden fn '||to_char(v_orden));
   if v_orden = p_orden then
      return 0; -- se completo el circuito
   end if;
   return 1;
END;
Begin

Declare
   v_orden                  ap_gru_tip_req.orden%type;
   v_cod_grupo              ap_gru_tip_req.cod_grupo%type;
   v_cod_tip_requerimiento  ap_tip_requerimientos.cod_tip_requerimiento%type;
   v_cod_usuario            ap_requerimientos.cod_usuario%type;

Begin
   if inserting then
    if :new.cod_grupo is null
        or :new.estado is null then
        raise_application_error(-20000,
        'Existen datos nulos');
    end if;

    elsif updating then
       if :old.estado = 'P' and :new.estado = 'A' then
          select cod_tip_requerimiento, cod_usuario
          into v_cod_tip_requerimiento, v_cod_usuario
          from ap_requerimientos
          where cod_requerimiento = :new.cod_requerimiento;

          --Buscar cod_grupo al que pertenece el usuario
          v_cod_grupo := fuy_obt_grupo(v_cod_usuario);

          --Verifica si es el ultimo nivel del circuito de aprobación.
          if lf_ver_nivelcircuito(v_cod_grupo, v_cod_tip_requerimiento, :new.orden) = 0 then

             update ap_requerimientos
             set estado = 'A'
             where cod_requerimiento = :new.cod_requerimiento;
          end if;
       elsif :old.estado = 'P'and :new.estado = 'C' then
         update ap_requerimientos
         set estado = 'C'
         where cod_requerimiento = :new.cod_requerimiento;
      end if;

    end if;


End;
End;
/

