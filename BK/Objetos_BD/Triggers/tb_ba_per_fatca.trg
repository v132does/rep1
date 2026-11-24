CREATE OR REPLACE TRIGGER IT.TB_BA_PER_FATCA
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_PER_FATCA
 FOR EACH ROW
DECLARE
v_tip_persona  ba_personas.tipo%type;


BEGIN
   if inserting or updating then
     begin 
       select tipo
         into v_tip_persona
         from ba_personas
        where cod_persona = :new.cod_persona;
     exception
        when no_data_found then
          null;
         when others then
          raise_application_error(-20000,'Error. No se puede obtener tipo de persona'||sqlerrm);
      end;   
      
      if nvl(:old.estado,'X') != nvl(:new.estado,'X') then
         PAE_FAT.PR_ACT_PAR_FATCA( :new.cod_persona, v_tip_persona, 'EST_INI_FATCA',:new.estado);
      end if;
       
      if nvl(:old.nro_identificador,'X') != nvl(:new.nro_identificador,'X') then
        PAE_FAT.PR_ACT_PAR_FATCA(:new.cod_persona, v_tip_persona, 'TIN_EIN_FATCA',:new.nro_identificador);
      end if; 

      if nvl(:old.estado,'X') != nvl(:new.estado,'X') then
        :new.usu_ult_act_estado := substr(user,1,10);
        :new.fec_ult_act_estado := sysdate;        
      end if;
       :new.pro_actualizacion := pae_cnf.G_PROGRAMA;      
   end if;
EXCEPTION
   WHEN OTHERS THEN
     raise_application_error(-20000,'Error. TB_BA_PER_FATCA'||sqlerrm);
END;
/

