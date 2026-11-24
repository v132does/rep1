CREATE OR REPLACE FUNCTION IT.FUG_OBT_MTO_MAXIMO
 (P_COD_USUARIO IN VARCHAR2
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE DEFAULT NULL
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE DEFAULT NULL
 )
 RETURN NUMBER
 IS

V_MTO_MAXIMO GE_USU_LIMITES.MTO_MAXIMO%TYPE;
BEGIN
    --Busco el monto maximo por modalidad, modulo, usuario
		begin
        select max(case when a.cod_moneda = p_cod_moneda then
                      a.mto_maximo
                   else
                      pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                   end)
             into v_mto_maximo
        from ge_usu_limites a, ba_usuarios b
        where b.cod_usuario = p_cod_usuario
            and nvl(a.cod_modulo,-8) = nvl(p_cod_modulo,-9)
            and nvl(a.cod_modalidad,-8) = nvl(p_cod_modalidad,-9)
            and a.cod_usuario = p_cod_usuario;
    exception
    		when others then v_mto_maximo:=null;
    end;

		--Busco el monto maximo por modulo, usuario
    if v_mto_maximo is null then
    		begin
            select max(case when a.cod_moneda = p_cod_moneda then
                        a.mto_maximo
                    else
                        pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                    end)
                 into v_mto_maximo
            from ge_usu_limites a, ba_usuarios b
            where b.cod_usuario = p_cod_usuario
                and nvl(a.cod_modulo,-8) = nvl(p_cod_modulo,-9)
                and a.cod_modalidad is null
                and a.cod_usuario = p_cod_usuario;
        exception
        		when others then v_mto_maximo:=null;
        end;
		end if;

		--Busco el monto por usuario
    if v_mto_maximo is null then
    		begin
            select max(case when a.cod_moneda = p_cod_moneda then
                        a.mto_maximo
                    else
                        pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                    end)
                into v_mto_maximo
            from ge_usu_limites a, ba_usuarios b
            where b.cod_usuario = p_cod_usuario
                and a.cod_modulo is null
                and a.cod_modalidad is null
                and a.cod_usuario = p_cod_usuario;
        exception
        		when others then v_mto_maximo:=null;
        end;
		end if;


    --Busco el monto maximo por modalidad, modulo, categoria
    if v_mto_maximo is null then
    		begin
            select max(case when a.cod_moneda = p_cod_moneda then
                        a.mto_maximo
                    else
                        pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                    end)
                into v_mto_maximo
            from ge_usu_limites a, ba_usuarios b
            where b.cod_usuario = p_cod_usuario
                and nvl(a.cod_modulo,-8) = nvl(p_cod_modulo,-9)
                and nvl(a.cod_modalidad,-8) = nvl(p_cod_modalidad,-9)
                and a.categoria = b.categoria;
        exception
        		when others then raise_application_error(-20000,'QUE PASA... '||sqlerrm);
						--when others then v_mto_maximo:=null;
        end;
		end if;


    --Busco el monto maximo modulo, categoria
    if v_mto_maximo is null then
    		begin
            select max(case when a.cod_moneda = p_cod_moneda then
                        a.mto_maximo
                    else
                        pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                    end)
                into v_mto_maximo
            from ge_usu_limites a, ba_usuarios b
            where b.cod_usuario = p_cod_usuario
                and nvl(a.cod_modulo,-8) = nvl(p_cod_modulo,-9)
                and a.cod_modalidad is null
                and a.categoria = b.categoria;
        exception
        		when others then v_mto_maximo:=null;
        end;
		end if;

    --Busco el monto por categoria
    if v_mto_maximo is null then
    		begin
            select max(case when a.cod_moneda = p_cod_moneda then
                        a.mto_maximo
                    else
                        pag_gen.fu_con_mon_a_moneda(a.cod_moneda,p_cod_moneda,a.mto_maximo)
                    end)
                into v_mto_maximo
            from ge_usu_limites a, ba_usuarios b
            where b.cod_usuario = p_cod_usuario
                and a.cod_modulo is null
                and a.cod_modalidad is null
                and a.categoria = b.categoria;
        exception
        		when others then v_mto_maximo:=null;
        end;
		end if;
    
		if v_mto_maximo is null then
    		v_mto_maximo:=0;
		end if;
    return v_mto_maximo;
END;
/

