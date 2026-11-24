CREATE OR REPLACE TRIGGER IT.TB_WF_CIR_TAREAS
  BEFORE UPDATE
     ON "IT"."WF_CIR_TAREAS"
    FOR EACH ROW
DECLARE
  --v_cod_error number := 0;
  v_long number;
  v_cod_persona      ba_personas.cod_persona%type;
  v_cod_id_crear     ba_per_ima_documentos.cod_id_crear%type;
BEGIN
  IF updating THEN
     if :old.estado = 'P' and :new.estado in ('A','C','R') then
        -- MODIFICO LOS datos
        :new.cod_usuario := substr(user,1,10);
        :new.fec_finalizacion := sysdate;
         
     end if;
     begin
       v_long := sys.dbms_lob.getlength(:new.documento);  
       if nvl(v_long,0) > 2000 then
          :new.ind_anexo := '*';
       else
          :new.ind_anexo :=  null;
       end if;            
     exception
        when others then
           null;
     end;   
  END IF;
  
  IF (updating or inserting)  and :new.cod_tip_circuito in (51,82) THEN
           begin
             select t.cod_persona
               into v_cod_persona
               from wf_circuitos t
              where t.cod_circuito = :new.cod_circuito
                and t.cod_tip_circuito = :new.cod_tip_circuito
                and t.cod_tar_actual = 1;
           exception
             when others then
               v_cod_persona := null;
           end;
           begin
             Select t.cod_id_crear
               into v_cod_id_crear
               from ba_per_ima_documentos t
              where t.cod_persona = v_cod_persona
                and t.cod_tip_documento =
                    decode(:new.cod_tip_circuito, 51, 68, 82, 67);
           exception
             when others then
               v_cod_id_crear := null;
           end;
         if v_cod_persona is not null and :new.estado in ('R','A') then
             begin
                  insert into ba_per_ima_doc_estados
                    (COD_PERSONA, COD_CIRCUITO, RES_WF, COD_ID_CREAR )
                  values
                    (v_cod_persona, :new.cod_circuito, :new.estado, v_cod_id_crear);
             exception
             when others then
                  raise_application_error(-20000, 'TB_WF_CIR_TAREAS Insert en  ba_per_ima_doc_estados ' || sqlerrm);
             end;
           end if;
END IF;
EXCEPTION
  when others then
     null;
END;
/

