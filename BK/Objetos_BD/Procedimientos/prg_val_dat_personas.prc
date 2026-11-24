CREATE OR REPLACE PROCEDURE IT.PRG_VAL_DAT_PERSONAS
 (P_COD_PERSONA IN VARCHAR2
 ,P_TIP_PERSONA IN VARCHAR2
 )
 IS
v_nom_procedimiento   ge_par_dinamicos.val_parametro%type := null;
   v_sentencia           varchar2(500);
   v_error               varchar2(500);
BEGIN
   --- Recuperar nombre de rutina dinamica
   BEGIN
      select val_parametro
        into v_nom_procedimiento
        from ge_par_dinamicos
       where parametro = 'PRO_VAL_PERSONAS';
   exception
      when no_data_found then null;
      when others then
         raise_application_error(-20000,
         'Rec.Val.Personas '||sqlerrm);
   END;
   if v_nom_procedimiento is not null then
      v_sentencia := 'BEGIN '||v_nom_procedimiento||'('||
                     ''''||p_cod_persona||''''||','||
                     ''''||p_tip_persona||''''||'); END;';
      sql_util.ejecute_dml(v_sentencia, v_error);
      if v_error is not null then
         raise_application_error(-20000,
         'Eje.Val.Personas '||v_error);
      end if;
   end if;
END;
/

