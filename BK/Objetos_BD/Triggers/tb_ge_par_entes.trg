CREATE OR REPLACE TRIGGER IT.TB_GE_PAR_ENTES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_PAR_ENTES
 FOR EACH ROW


DECLARE

v_sentencia           varchar2(500);
v_nom_procedimiento   varchar2(30);
v_error               varchar2(500):= null;
v_gparam              ge_parametros%rowtype;
v_tipo                ge_entes.tipo%type;


/* Obtener tipo de ente. */
FUNCTION LF_OBT_TIPO_ENTE
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 )
 RETURN VARCHAR2
 IS

BEGIN
   select tipo
   into v_tipo
   from ge_entes
   where cod_ente = p_cod_ente;
   return v_tipo;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Ente '||to_char(p_cod_ente)||' no registrado');
END;

BEGIN
   if inserting or updating then
      prg_obt_ge_parametro(:new.parametro, v_gparam);
      --- Verificar que el parámetro corresponda a la tabla de entes
      if v_gparam.tab_relacion <> 'GE_PAR_ENTES' then
         raise_application_error(-20000,
         'El parámetro '||:new.parametro||' no corresponde a esta tabla');
      end if;
      --- Verificar que el tipo de parámetro corresponda al tipo de ente a definir
      v_tipo := lf_obt_tipo_ente(:new.cod_ente);
      if ltrim(rtrim(v_gparam.referencia)) not in (v_tipo, 'TO') then
         raise_application_error(-20000,
         'El parámetro no corresponde a este tipo de ente: '||v_tipo);
      end if;
      --- VERIFICACION DE VALORES INGRESADOS
      if inserting or updating then
         SELECT UPPER(rtrim(pro_verificacion))
          INTO v_nom_procedimiento
          FROM GE_PARAMETROS
         WHERE TAB_RELACION = 'GE_PAR_ENTES'
           AND PARAMETRO    = :new.parametro;

        --se agregó que val_parámetro tenga valor sino cae x error al tratar de validar
        If v_nom_procedimiento is not null and :new.val_parametro is not null then
           v_sentencia := 'BEGIN '||v_nom_procedimiento||'('||
                       ''''||:new.val_parametro||''''||'); END;';
           sql_util.ejecute_dml(v_sentencia, v_error);
           If v_error is not null then
              v_error := 'Valor incorrecto. Verifique .'||v_nom_procedimiento;
              raise_application_error(-20000, v_error);
           End if;
        End if;
      End if;
      ---- FIN VERIFICACION AGREGADA
   end if;
END;
/

