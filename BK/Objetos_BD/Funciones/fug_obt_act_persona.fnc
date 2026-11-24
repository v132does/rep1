create or replace function it.fug_obt_act_persona( p_cod_persona in varchar2 )
return varchar2 is
   vactividad varchar2(4);
   vtipo      varchar2(1);
   vpep       varchar2(1);
   vcodigo    varchar2(5);

   cursor cvalores is
          select *
            from cr_pun_valores
           where cod_puntaje = 10
             and cod_campo = 'MR_ACTIVID'
            order by puntaje desc, descripcion;
   cursor cactividades is
          select *
            from cr_inf_laborales
           where cod_persona = p_cod_persona
             and actual = 'S';
BEGIN

     BEGIN
          select tipo
            into vtipo
            from ba_personas
           where cod_persona = p_cod_persona;
     END;
     FOR x in cvalores loop

         vcodigo := ltrim( rtrim( substr( x.descripcion, 1, instr( x.descripcion, '-', 1, 1 ) - 1 ) ) );
         IF vcodigo = 'PEP' THEN

            BEGIN
                 select nvl( pep, 'N' )
                   into vpep
                   from cr_inf_fondos
                  where cod_persona = p_cod_persona;
            EXCEPTION
               WHEN others THEN
                   vpep := 'N';
            END;
            IF vpep = 'S' THEN
               return( vcodigo );
               exit;
            END IF;

         ELSIF vcodigo not in ( 'ABO', 'CON', 'ESC' ) THEN

               IF vtipo = 'F' THEN
                  for y in cactividades loop
                      IF vcodigo = 'FPEP' and y.cod_ramo = '211' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'CMP' and y.cod_ramo = '212' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'COA' and y.cod_ramo = '213' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ANT' and y.cod_ramo = '214' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'NUM' and y.cod_ramo = '215' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FIL' and y.cod_ramo = '216' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'JUE' and y.cod_ramo = '217' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'INM' and y.cod_ramo = '116' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FUD' and y.cod_ramo = '218' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'EMP' and y.cod_ramo = '219' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'CAM' and y.cod_ramo = '220' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'SEG' and y.cod_ramo = '221' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FIN' and y.cod_ramo = '209' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'CAR' and y.cod_ramo = '222' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ARM' and y.cod_ramo = '223' and y.tip_cargo = 'A' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ONG' and y.cod_ramo = '224' and y.tip_cargo = 'J' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FMU' and y.cod_ramo = '225' and y.tip_cargo = 'J' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'JUB' and y.tip_cargo = 'B' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'IEX' and y.cod_ramo = '226' THEN
                         return( vcodigo );
                         exit;
                      END IF;
                  end loop;
               ELSIF vtipo = 'J' THEN
                      BEGIN
                         select cod_ramo
                           into vactividad
                           from ba_per_juridicas
                          where cod_persona = p_cod_persona;
                      EXCEPTION
                         WHEN others THEN
                           null;
                      END;
                      IF vcodigo = 'CMP' and vactividad = '212' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'COA' and vactividad = '213' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ANT' and vactividad = '214' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'NUM' and vactividad = '215' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FIL' and vactividad = '216' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'JUE' and vactividad = '217' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'INM' and vactividad = '116' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FUD' and vactividad = '218' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'EMP' and vactividad = '219' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'CAM' and vactividad = '220' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'SEG' and vactividad = '221' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FIN' and vactividad = '209' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'CAR' and vactividad = '222' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ARM' and vactividad = '223' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'ONG' and vactividad = '224' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'FMU' and vactividad = '225' THEN
                         return( vcodigo );
                         exit;
                      ELSIF vcodigo = 'IEX' and vactividad = '226' THEN
                         return( vcodigo );
                         exit;
                      END IF;
                END IF;

         ELSE

               BEGIN
                    select cod_profesion
                      into vactividad
                      from ba_per_fisicas
                     where cod_persona = p_cod_persona;
               EXCEPTION
                  WHEN others THEN
                     null;
               END;
               IF vcodigo = 'ABO' and vactividad = '2' THEN
                  return( vcodigo );
                  exit;
               ELSIF vcodigo = 'CON' and vactividad = '1' THEN
                  return( vcodigo );
                  exit;
               ELSIF vcodigo = 'ESC' and vactividad = '10' THEN
                  return( vcodigo );
                  exit;
               END IF;

         END IF;

     END LOOP;


     return( 'OTR' );


END;
/

