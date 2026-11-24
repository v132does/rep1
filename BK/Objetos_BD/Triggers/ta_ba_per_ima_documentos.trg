CREATE OR REPLACE TRIGGER IT.TA_BA_PER_IMA_DOCUMENTOS
  AFTER INSERT
     ON BA_PER_IMA_DOCUMENTOS
    FOR EACH ROW
DECLARE
  v_resp number;
  v_desc varchar2(1000);
  v_nombre varchar2(100);
  v_ci varchar2(100);
  v_destinatario ge_par_dinamicos.val_parametro%type;
BEGIN
  IF INSERTING THEN
    --Tipo de documento 'Contrato Unico'
    IF :new.cod_tip_documento = 64 then
       v_resp := paw_cir.FU_INI_CIRCUITO(48, :new.cod_persona, :new.cod_persona);
       v_destinatario:= fug_obt_pardinamico('MAI_ONB_PER_BO');  
    --Se obtiene los datos de la persona
    begin
      select 'Nombre: ' || a.pri_nombre || ' ' || a.pri_apellido ,' Ci: ' ||
             b.nro_documento
        into v_nombre, v_ci
        from ba_per_fisicas a, ba_personas b
       where a.cod_persona = :new.cod_persona
         and a.cod_persona = b.cod_persona;
    EXCEPTION
        when others then
             v_desc :=' ';
    end; 
    v_desc := 'Fecha: '||TO_char(:new.fec_insercion,'dd/mm/yyyy HH24:MI:SS') ||chr(10)||chr(13)||
             v_nombre||chr(10)||chr(13)||
             v_ci||chr(10)||chr(13)||
             'Estado: Pendiente Validacion'||chr(10)||chr(13)||
             'ATM: '||:new.observacion;
    
    --Enviar notificacion al correo configurado
    it_mail.mail(fug_obt_dir_correo, 
                   v_destinatario,
                   'Verificacion de acuse de CU BackOffice',
                   v_desc);
    END IF;
   END IF;
EXCEPTION
  when others then
     null;
END;
/

