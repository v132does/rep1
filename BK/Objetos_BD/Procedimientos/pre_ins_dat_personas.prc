create or replace procedure it.pre_ins_dat_personas is

  v_can_mail  float := 0;
  v_can_dir   float := 0;
  v_can_tel   float := 0;
  
  v_mail_row  ba_mails%rowtype;
  v_tel_row   ba_telefonos%rowtype;
  v_dir_row   ba_direcciones%rowtype;
  
begin
  -- Author  : Gabriel Capo
  -- Created : 19/12/2013
  -- Purpose : Inserta datos de clientes en las tablas : ba_telefonos, ba_direcciones, ba_mails, a través del proc. importacion de datos ACT_DATOS_TMP

  begin pre_ini_aplicacion;  pae_cnf.G_COD_MODULO := 1; end;
  
  for xx in (select a.cod_persona,
                   a.dir_correo,
                   a.telefono,
                   a.direccion
              from BA_DAT_PERSONAS_TMP a, ba_personas b
             where a.cod_persona = b.cod_persona) loop
             
    
    -----------------------BA_MAIL-----------------------------
    ----------------------------------------------------------- 
    if xx.dir_correo is not null then
      
      v_mail_row.cod_persona  := xx.cod_persona;
      v_mail_row.tipo         := 'M';
      v_mail_row.dir_correo   := xx.dir_correo;
      v_mail_row.principal    := 'N';
    
      select count(1)
        into v_can_mail
        from ba_mails dd
       where dd.cod_persona = v_mail_row.cod_persona
         and upper(trim(dd.dir_correo)) = upper(trim(v_mail_row.dir_correo));
         
      if v_can_mail = 0 then
         
         insert into ba_mails values v_mail_row;
      
      end if;
    
    end if;
    
    ----------------------BA_DIRECCIONES---------------------------
    ----------------------------------------------------------------
    if XX.DIRECCION is not null then
       
        v_dir_row.cod_persona   := xx.cod_persona;
        v_dir_row.tipo          := 'O';
        v_dir_row.principal     := 'N';
        v_dir_row.direccion     := xx.direccion;
        v_dir_row.cod_pais      := '1';
        
        select count(1)
          into v_can_dir
          from ba_direcciones dd
         where dd.cod_persona = v_dir_row.cod_persona;
        
        v_dir_row.cod_direccion := v_can_dir + 1;
        
        v_can_dir := 0;
        
        select count(1)
          into v_can_dir
          from ba_direcciones dd
         where dd.cod_persona = v_dir_row.cod_persona
           and upper(trim(dd.direccion)) = upper(trim(v_dir_row.direccion));
             
        if v_can_dir = 0 then
             
           insert into ba_direcciones values v_dir_row;
          
        end if;
        
    end if;
    
    -----------------------BA_TELEFONOS----------------------------
    ---------------------------------------------------------------
    if xx.telefono is not null then
    
        v_tel_row.cod_persona   := xx.cod_persona;
        v_tel_row.tipo          := 'M';
        v_tel_row.tip_linea     := 'C';
        
        v_tel_row.telefono      := substr(xx.telefono,5,10);
        v_tel_row.principal     := 'N';
        v_tel_row.area          := substr(xx.telefono,0,4);
        v_tel_row.interno       := '0';
        
        select max(dd.cod_telefono)
          into v_can_tel
          from ba_telefonos dd
         where dd.cod_persona = v_tel_row.cod_persona;
        
        v_tel_row.cod_telefono  := v_can_tel + 1; 
        
        v_can_tel := 0;
        
        select count(1)
          into v_can_tel
          from ba_telefonos dd
         where dd.cod_persona = v_tel_row.cod_persona
           and trim(dd.telefono) = trim(v_tel_row.telefono)
           and trim(dd.area) = trim(v_tel_row.area);
                  
        if v_can_tel = 0 then
           
           insert into ba_telefonos values v_tel_row;
        
        end if;
        
    end if;
     
  end loop;
  
end pre_ins_dat_personas;
/

