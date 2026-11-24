CREATE OR REPLACE PROCEDURE IT.PRG_OBT_MTO_MAXIMO
 (P_COD_USUARIO IN VARCHAR2
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE DEFAULT NULL
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE DEFAULT NULL
 ,P_MTO_MAXIMO    IN OUT GE_USU_LIMITES.MTO_MAXIMO%TYPE
 ,P_NIV_APROBACION IN OUT GE_USU_LIMITES.NIV_APROBACION%TYPE
 )
 IS

BEGIN
   P_MTO_MAXIMO := 0;
   -- busqueda si existe en la moneda
   if p_cod_modulo = 4 then  -- busca el limite especifico para sobregiros
       begin
       select A.MTO_MAXIMO, A.NIV_APROBACION
         into P_MTO_MAXIMO, P_NIV_APROBACION
         from GE_USU_LIMITES A, BA_USUARIOS B
        where B.COD_USUARIO = P_COD_USUARIO
        and A.COD_MONEDA = P_COD_MONEDA
        and a.cod_modulo = p_cod_modulo
        and (A.COD_USUARIO = P_COD_USUARIO OR (A.COD_USUARIO IS NULL AND A.CATEGORIA = B.CATEGORIA))
        and (A.MTO_MAXIMO) = (select max(az.mto_maximo)
                                from GE_USU_LIMITES Az, BA_USUARIOS Bz
                               where Bz.COD_USUARIO = P_COD_USUARIO
                                 and Az.COD_MONEDA = P_COD_MONEDA
                                 and AZ.COD_MODULO = 4
                                 and (Az.COD_USUARIO = P_COD_USUARIO OR (Az.COD_USUARIO IS NULL AND Az.CATEGORIA = Bz.CATEGORIA)))
        and rownum = 1;
       exception 
          when others then P_mto_maximo := null;
       end;
       if P_mto_maximo is null then
           -- busqueda si existe en otra moneda y se convierte a la moneda que se envia
           begin
           select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,A.MTO_MAXIMO), NIV_APROBACION
             into P_MTO_MAXIMO, P_NIV_APROBACION
             from GE_USU_LIMITES A, BA_USUARIOS B
            where B.COD_USUARIO = P_COD_USUARIO
            and A.COD_MONEDA <> P_COD_MONEDA
            and a.cod_modulo = p_cod_modulo
            and (A.COD_USUARIO = P_COD_USUARIO OR (A.COD_USUARIO IS NULL AND A.CATEGORIA = B.CATEGORIA))
            and (A.MTO_MAXIMO) = (select max(az.mto_maximo)
                                    from GE_USU_LIMITES Az, BA_USUARIOS Bz
                                   where Bz.COD_USUARIO = P_COD_USUARIO
                                     and Az.COD_MONEDA <> P_COD_MONEDA
                                     and az.cod_modulo = 4
                                     and (Az.COD_USUARIO = P_COD_USUARIO OR (Az.COD_USUARIO IS NULL AND Az.CATEGORIA = Bz.CATEGORIA)))
            and rownum = 1;
           exception 
              when others then P_mto_maximo := 0;
           end;       
       end if;    
   else    
       begin
       select A.MTO_MAXIMO, A.NIV_APROBACION
         into P_MTO_MAXIMO, P_NIV_APROBACION
         from GE_USU_LIMITES A, BA_USUARIOS B
        where B.COD_USUARIO = P_COD_USUARIO
        and A.COD_MONEDA = P_COD_MONEDA
        and (nvl(a.cod_modulo,-9) = nvl(p_cod_modulo,-9) or a.cod_modulo is null)
        and (trim(to_char(nvl(a.cod_modalidad,-9)))  like nvl(p_cod_modalidad, nvl(p_cod_modulo, -9))||'%' or a.cod_modalidad is null)
        and (A.COD_USUARIO = P_COD_USUARIO OR (A.COD_USUARIO IS NULL AND A.CATEGORIA = B.CATEGORIA))
        and (A.MTO_MAXIMO) = (select max(az.mto_maximo)
                                from GE_USU_LIMITES Az, BA_USUARIOS Bz
                               where Bz.COD_USUARIO = P_COD_USUARIO
                                 and Az.COD_MONEDA = P_COD_MONEDA
                                 and (nvl(az.cod_modulo,-9) = nvl(p_cod_modulo,-9) or az.cod_modulo is null)
                                 and (trim(to_char(nvl(az.cod_modalidad,-9))) like nvl(p_cod_modalidad, nvl(p_cod_modulo, -9))||'%' or az.cod_modalidad is null)
                                 and (Az.COD_USUARIO = P_COD_USUARIO OR (Az.COD_USUARIO IS NULL AND Az.CATEGORIA = Bz.CATEGORIA)))
        and rownum = 1;
       exception 
          when others then P_mto_maximo := null;
       end;
       if P_mto_maximo is null then
           -- busqueda si existe en otra moneda y se convierte a la moneda que se envia
           begin
           select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,A.MTO_MAXIMO), NIV_APROBACION
             into P_MTO_MAXIMO, P_NIV_APROBACION
             from GE_USU_LIMITES A, BA_USUARIOS B
            where B.COD_USUARIO = P_COD_USUARIO
            and A.COD_MONEDA <> P_COD_MONEDA
            and (nvl(a.cod_modulo,-9) = nvl(p_cod_modulo,-9) or a.cod_modulo is null)
            and (nvl(a.cod_modalidad,-9) = nvl(p_cod_modalidad,-9) or a.cod_modalidad is null)
            and (A.COD_USUARIO = P_COD_USUARIO OR (A.COD_USUARIO IS NULL AND A.CATEGORIA = B.CATEGORIA))
            and (A.MTO_MAXIMO) = (select max(az.mto_maximo)
                                    from GE_USU_LIMITES Az, BA_USUARIOS Bz
                                   where Bz.COD_USUARIO = P_COD_USUARIO
                                     and Az.COD_MONEDA <> P_COD_MONEDA
                                     and (nvl(az.cod_modulo,-9) = nvl(p_cod_modulo,-9) or az.cod_modulo is null)
                                     and (nvl(az.cod_modalidad,-9) = nvl(p_cod_modalidad,-9) or az.cod_modalidad is null)
                                     and (Az.COD_USUARIO = P_COD_USUARIO OR (Az.COD_USUARIO IS NULL AND Az.CATEGORIA = Bz.CATEGORIA)))
             and rownum = 1;
           exception 
              when others then P_mto_maximo := 0;
           end;       
       end if;    
   end if;
EXCEPTION
   when no_data_found then
        raise_application_error(-20000,'No existe limite en GE_USU_LIMITES');
END;
/

