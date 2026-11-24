CREATE OR REPLACE FUNCTION IT.FUA_PUE_VER_CARTON
 (P_COD_RESPONSABLE IN AH_CER_GRUPOS.COD_USU_RESPONSABLE%TYPE
 ,P_COD_OFICINA IN AH_CER_GRUPOS.COD_OFICINA%TYPE
 )
 RETURN VARCHAR2
 IS
v_puede_ver varchar2(1) := 'N';
begin
   If p_cod_responsable = user then
     -- si es el encargado del grupo lo puede ver
     v_puede_ver := 'S';
   else
     -- si es el encargado de la Agencia puede ver lo de la Agencia
     begin
       select 'S'
         into v_puede_ver
         from ba_oficinas
        where cod_oficina = p_cod_oficina
          and cod_usu_encargado = user;
     exception
        when no_data_found then
          v_puede_ver := 'N';
     end;
     if v_puede_ver = 'N' then
       -- si es el operativo de la agencia, debe ver lo de la Agencia
       begin
         select 'S'
           into v_puede_ver
           from ba_usuarios z, ba_usu_roles x
          where x.cod_usuario = user
            --and x.cod_rol like '%OPERATIV%'  31/10/13 SF: para que el control por roles sea dinamico
            and exists (SELECT 1
                          FROM ba_cod_referencias  a
                         WHERE a.dominio = 'AHO_VER_OFI_CARTONES'
                           and a.val_minimo = x.cod_rol)
            and z.cod_usuario = x.cod_usuario
            and z.cod_oficina = p_cod_oficina
            and rownum = 1;
       exception
          when no_data_found then
            v_puede_ver := 'N';
       end;  
       if v_puede_ver = 'N' then   
         -- Si el usuario es de Auditoria, Administrativo, suministro u Operaciones puede ver todo 
         begin
           select 'S'
             into v_puede_ver
             from ba_usu_roles x
            where x.cod_usuario = user
              /*and (x.cod_rol like '%OPERAC%' or 
                   x.cod_rol like '%AUDITOR%' or 
                   x.cod_rol like  '%ADMINIS%' or 
                   x.cod_rol like '%SUMINIS%')*/
              --31/10/13 SF: para que el control por roles sea dinamico
              and exists (SELECT 1
                          FROM ba_cod_referencias  a
                         WHERE a.dominio = 'AHO_VER_CARTONES'
                           and a.val_minimo = x.cod_rol )
              and rownum = 1;
         exception
            when no_data_found then
              v_puede_ver := 'N';
         end; 
       end if;
     end if;           
   End if;
   return v_puede_ver;
end;
/

