create or replace procedure it.prc_ver_che_rec_aut
                              ( p_nro_cuenta      in varchar2,
                                p_nro_cheque      in number,
                                p_estado          in varchar2,
                                p_rec_aut         out varchar2,
                                p_cod_cau_rechazo out varchar2,
                                p_des_cau_rechazo out varchar2) is
   v_cod_cau_rechazo       varchar2(10);
   v_des_cau_rechazo       varchar2(2000);
   v_rec_aut               varchar2(1):= 'N';
   v_est_cheque            ge_cuentas.estado%type;
   v_error                 varchar2(2000);
begin
   --Se verifica si esta activo el rechazo automatico
   if nvl(fug_obt_pardinamico('CC_ACT_REC_AUT'),'N') = 'S' THEN
     --Para Verificar Orden de No Pago
     v_est_cheque := pac_che.fu_obt_est_che(p_nro_cuenta,p_nro_cheque,v_error,null);
         
     if v_error is null then
        if v_est_cheque = 'O' then
           begin
              select w.val_maximo, w.abreviatura
                into v_cod_cau_rechazo, v_des_cau_rechazo
                from ba_cod_referencias w
               where w.dominio = 'RECHAZO_AUTOMATICO'
                 and w.val_minimo = 'O';
                  
              v_rec_aut:='S';
           exception 
              when others then
                 v_rec_aut:='N';                     
           end;             
        End if;
     end if;      
      
     --Si aun no se rechazo automaticamente por ONP, verificamos el estado de la Cuenta
     if v_rec_aut ='N' then 
        --Verifica datos de cuentas en estado Canceladas o Pendientes de Cancelacion  
        if p_estado in ('C','P') then
           begin
              select w.val_maximo, w.abreviatura
                into v_cod_cau_rechazo, v_des_cau_rechazo
                from ba_cod_referencias w
               where w.dominio='RECHAZO_AUTOMATICO'
                 and w.val_minimo= 'C';
                
              v_rec_aut:='S';
           exception
              when others then
                 v_rec_aut:='N';                     
           end;  
        end if;   
      
        --Verifica datos de cuentas en estado Bloqueadas
        if p_estado in ('T') then
           begin
              select w.val_maximo, w.abreviatura
                into v_cod_cau_rechazo, v_des_cau_rechazo
                from ba_cod_referencias w
               where w.dominio='RECHAZO_AUTOMATICO'
                 and w.val_minimo= 'T';
                  
              v_rec_aut:='S';
           exception
              when others then
                 v_rec_aut:='N';                     
           end;  
        end if;
      end if;
   end if;
   
   p_rec_aut:= v_rec_aut;
   p_cod_cau_rechazo:= v_cod_cau_rechazo;
   p_des_cau_rechazo:= v_des_cau_rechazo;
   
exception
   when others then
      p_rec_aut:='N';
end;
/
