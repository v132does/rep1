CREATE OR REPLACE TRIGGER IT.TB_BA_VINCULOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_VINCULOS
 FOR EACH ROW
DECLARE
   v_ins_vinculos_nov varchar2(1) default 'N';
   rv_scvno        sb_cta_vinculos_nov%rowtype;
   /* Obtener sexo y estado civil de la persona. */
PROCEDURE LP_OBT_SEX_EST_CIVIL
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_SEXO IN OUT BA_PER_FISICAS.COD_SEXO%TYPE
 ,P_EST_CIVIL IN OUT BA_PER_FISICAS.EST_CIVIL%TYPE
 );
   v_cod_sexo           ba_per_fisicas.cod_sexo%type;
   v_cod_sex_vinculo    ba_per_fisicas.cod_sexo%type;
   v_est_civil          ba_per_fisicas.est_civil%type;
   v_est_civ_vinculo    ba_per_fisicas.est_civil%type;
   v_cantidad           number(05);
   v_existe             varchar2(1):= 'N';


/* Obtener sexo y estado civil de la persona. */
PROCEDURE LP_OBT_SEX_EST_CIVIL
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_SEXO IN OUT BA_PER_FISICAS.COD_SEXO%TYPE
 ,P_EST_CIVIL IN OUT BA_PER_FISICAS.EST_CIVIL%TYPE
 )
 IS
BEGIN
   select cod_sexo, est_civil
     into p_cod_sexo, p_est_civil
     from ba_per_fisicas
    where cod_persona = p_cod_persona;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Persona Física '||p_cod_persona||' no registrada');
END;

/* Es Persona Física. */
function LF_ES_PER_FISICA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
) RETURN VARCHAR2 IS

 v_es_fisica varchar2(1);

BEGIN
   select 'S'
     into v_es_fisica
     from ba_per_fisicas
    where cod_persona = p_cod_persona;

    return v_es_fisica;    
exception
   when no_data_found then
      v_es_fisica := 'N';
      return v_es_fisica;
   when others then
      v_es_fisica := 'N';
      return v_es_fisica;
END;

BEGIN

   if inserting then
      --DE-2588 - Ajuste de funcionamiento en carga de Estado Civil Union de Hecho - DYD-SDSL-3499 - DIC/2016
      if :new.tipo in ('E', 'C') then
         --- Recuperar sexo y estado civil de las personas vinculadas
         --- para validar vinculo de esposos
         LP_OBT_SEX_EST_CIVIL(:new.cod_persona, v_cod_sexo, v_est_civil);
         LP_OBT_SEX_EST_CIVIL(:new.cod_per_vinculo, v_cod_sex_vinculo, v_est_civ_vinculo);

         if :new.cod_persona = :new.cod_per_vinculo then
            raise_application_error(-20001,
            'El código de las personas vinculadas como esposos debe ser diferente');
         end if;         

         if v_cod_sexo = v_cod_sex_vinculo then
            raise_application_error(-20001,
            'El sexo de las personas vinculadas como esposos debe ser diferente');
         end if;

        
         /*
         if v_est_civil not in ('C','B') then
            raise_application_error(-20001,
            'El estado civil de la persona '||:new.cod_persona||' debe ser casada');
         end if;
         if v_est_civ_vinculo not in ('C','B') then
            raise_application_error(-20001,
            'El estado civil de la persona '||:new.cod_per_vinculo||' debe ser casada');
         end if;
         --- Verificar si la persona ya posee otro conyuge
         BEGIN
            select count(*)
              into v_cantidad
              from ba_vinculos
             where tipo = 'E'
               and ((cod_persona = :new.cod_persona     and cod_per_vinculo <> :new.cod_per_vinculo)
                 or (cod_persona = :new.cod_per_vinculo and cod_per_vinculo <> :new.cod_persona));
            if v_cantidad > 0 then
               raise_application_error(-20001,
               'Personas vinculadas poseen vinculos de esposos con otras personas');
            end if;
         END;
         */
      end if;
                   
       begin
        select ven_obligatorio
          into v_existe
          from ba_tip_vinculos
         where cod_tip_vinculo = :new.tipo;
        If v_existe = 'S' and :new.FEC_VENCIMIENTO is null then
          raise_application_error(-20001,
          'El tipo de vinculo debe tener vencimiento');
        End if;
      exception
        when no_data_found then
        null;
      end;
   end if;
   
   If updating then
     If :new.tipo <> :old.tipo then
       begin
         select ven_obligatorio
          into v_existe
          from ba_tip_vinculos
         where cod_tip_vinculo = :new.tipo;
         If v_existe = 'S' and :new.FEC_VENCIMIENTO is null then
          raise_application_error(-20001,
          'El tipo de vinculo debe tener vencimiento');
         End if;
       exception
         when no_data_found then
         null;
       end;
     End  if;
   End if;
   
   if inserting or updating then 
	--DE-2588 - Ajuste de funcionamiento en carga de Estado Civil Union de Hecho - DYD-SDSL-3499 - DIC/2016
        if :new.tipo in ('E','C','CD') and (LF_ES_PER_FISICA(:new.cod_persona) = 'S'
                                             and 
                                            LF_ES_PER_FISICA (:new.cod_per_vinculo) = 'S') then      
           LP_OBT_SEX_EST_CIVIL(:new.cod_persona, v_cod_sexo, v_est_civil);
           LP_OBT_SEX_EST_CIVIL(:new.cod_per_vinculo, v_cod_sex_vinculo, v_est_civ_vinculo);

          -- Si el estado civil de la persona es Casado sin separación de bienes (C)
          -- no puede estar vinculado a la otra persona como Concubino (C)
          ---   estado civil = C    vinculo.tipo no puede ser C
          If (v_est_civil in ('C','B') and :new.tipo = 'C') or
             (v_est_civ_vinculo in ('C','B') and :new.tipo = 'C') then
             raise_application_error(-20001,
            'Verificar estado civil de las personas '||:new.cod_persona||'-'||:new.cod_per_vinculo||
            '. Una o ambas no corresponde para el tipo de vinculo');            
          End if;

          -- Si el estado civil de la persona es Unión de Hecho no puede estar vinculado 
          -- a la otra persona como Conyuge(E)
          -- estado civil = U no puede existir como vinculo E 
          If (v_est_civil = 'U' and :new.tipo = 'E') or
             (v_est_civ_vinculo = 'U' and :new.tipo = 'E') then
             raise_application_error(-20001,
            'El estado civil de la persona '||:new.cod_persona||' no es correcta para el tipo de vinculo');            
          End if;      
       End if;
     End if;        
   
   IF deleting or inserting THEN
      v_ins_vinculos_nov := 'S';
      IF inserting AND :new.tipo = 'E' THEN
         IF (fus_ver_crc_vinculos(:new.cod_persona, :new.tipo, NULL)) = 'S' OR 
            (fus_ver_crc_vinculos(:new.cod_per_vinculo, :new.tipo, NULL) = 'S') THEN
            rv_scvno.evento := 'V';
            rv_scvno.cod_persona := :new.cod_persona; 
            rv_scvno.relacion := :new.tipo;            
         ELSE
            rv_scvno.evento := NULL;
         END IF;
      ELSIF deleting AND :old.tipo = 'E' THEN
         IF fus_ver_crc_vinculos(:old.cod_persona, :old.tipo, NULL) = 'S' OR
            fus_ver_crc_vinculos(:old.cod_per_vinculo, :old.tipo, NULL) = 'S' THEN
            rv_scvno.evento := 'D';
            rv_scvno.relacion := :old.tipo;               
            rv_scvno.cod_persona := :old.cod_persona; 
         END IF;      
      END IF;      
   END IF;
   IF nvl(v_ins_vinculos_nov, 'N') = 'S' AND (:new.tipo = 'E' OR :old.tipo = 'E') AND rv_scvno.evento IS NOT NULL THEN
      rv_scvno.fecha       := to_date(to_char(SYSDATE, 'DDMMYYYY') ||
                                      pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS')),
                                      'DDMMYYYY HH24:MI:SS');
      rv_scvno.hora        := pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS'));
      rv_scvno.nro_cuenta  := NULL;
      rv_scvno.cod_modulo  := NULL;
      BEGIN
         INSERT INTO sb_cta_vinculos_nov
            (fecha, hora, nro_cuenta, cod_persona, evento, relacion, cod_modulo)
         VALUES
            (rv_scvno.fecha, rv_scvno.hora, rv_scvno.nro_cuenta, rv_scvno.cod_persona,
             rv_scvno.evento, rv_scvno.relacion, rv_scvno.cod_modulo);
      EXCEPTION
         WHEN dup_val_on_index THEN
            NULL;
      END;
   END IF;
END;
/

