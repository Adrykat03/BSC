----Avisos el mismo jefe en jefe 1 y 2

CREATE   procedure [Avisos].[pa_avisos_jerarquias2]
    @tipo int
AS
Declare 
@tableHTML2 nvarchar(max),
@tableHTML nvarchar(max),
@tableHTML4 nvarchar(max),
@tableHTML3 nvarchar(max),
@tableHTML5 nvarchar(max),
@nombre varchar(100),
@query1 varchar(6000),
@cuerpo NVARCHAR(MAX),
@Dirigido varchar(300),
@copia varchar(100),
@w int=0,
@i int=0

set nocount on
Begin

    DECLARE @tabla AS TABLE (
        trabajador CHAR(10)  
        ,
        nombreTrab VARCHAR(250)  
        ,
        cco VARCHAR(15)  
        ,
        descCCO VARCHAR(250)  
        ,
        codigo VARCHAR(20)  
        ,
        nombre VARCHAR(200)  
        ,
        cargoHomologado SMALLINT  
        ,
        car VARCHAR(150)  
        )

    DECLARE @tabla2 AS TABLE (
        trabajador CHAR(10)  
            ,
        nombreTrab VARCHAR(250)  
            ,
        cco VARCHAR(15)  
            ,
        descCCO VARCHAR(250)  
            ,
        codigo VARCHAR(20)  
            ,
        nombre VARCHAR(200)  
            ,
        cargoHomologado SMALLINT  
            ,
        car VARCHAR(150)  
            )

    DECLARE @tabla12 AS TABLE (
        cco VARCHAR(15)  
        ,
        descCCO VARCHAR(250)  
        ,
        codigo VARCHAR(20)  
        ,
        nombre VARCHAR(200)  
        ,
        cargoHomologado SMALLINT  
        )
		 
          IF @tipo = 15
		  Begin

        Declare @tableJefe1Jefe2 as table (cco varchar(15),
            descripcion varchar(200),
            jefe1 varchar(20),
            jefe2 varchar(20))

        insert into @tableJefe1Jefe2
        select cco, descripcion , jefe1, jefe2
        from Catalogos.centro_costos C
        where jefe2  = jefe1
            and esLocal  = 'S' and estatus = 1

        SELECT
            cco,
            descripcion,
            jefe1,
            (SELECT TOP 1
                nombre
            FROM RRHH.vw_datosTrabajadores W
            WHERE W.codigo = T.jefe1) as NombreJefe
        FROM @tableJefe1Jefe2 T
        WHERE jefe1 = jefe2
        ORDER BY cco
    end 
		  else if @tipo = 16
		  Begin
        Declare @tableJefe1Jefe2CAR as table (trabajador varchar(25),
            nombre varchar(200),
            jefe1 varchar(20),
            nombreJefe1 varchar(250),
            jefe2 varchar(20),
            nombreJefe2 varchar(250))

        insert into @tableJefe1Jefe2CAR
        select trabajador, nombre, jefe1 , (Select top 1
                nombre
            from RRHH.vw_datosTrabajadores W
            where W.codigo = t.jefe1) as nombreJefe1,
            jefe2 , (Select top 1
                nombre
            from RRHH.vw_datosTrabajadores Z
            where Z.codigo = t.jefe2) as nombreJefe2
        from RRHH.vw_datosTrabajadores t
        where situacion  = 'Activo'
            and car like '%CAR%'
            and jefe1 = jefe2

        SELECT
            trabajador,
            nombre,
            jefe1,
            isnull(nombreJefe1,'')  as NombreJefe1,
            jefe2,
            isnull
			(nombreJefe2,'') as NombreJefe2
        from @tableJefe1Jefe2CAR
        order by trabajador

    end
		  else if @tipo = 17
		  Begin
          declare @tablaTrab1 as table(trabajador char(10), d int)

			insert into @tablaTrab1
			select trabajador, count(distinct Jefe2  )
			from rrhh.vw_datosTrabajadores
			where trabajador in ( select trabajador
				from adam.dbo.VW_TrabActivosmasUnaEmpresa) and Situacion = 'Activo'
			group by  Trabajador
			having count(distinct Jefe2 )>1

			declare @tabla6 as table (compania char(4),
				trabajador char(10),
				nombre varchar(200),
				jefe2 varchar(80),
				jefe2Ant varchar(80))

			insert into @tabla6
			select distinct '', trabajador, nombre, Jefe2 , ''
			from rrhh.vw_datosTrabajadores
			where trabajador in ( select trabajador
				from @tablaTrab1)
				and Situacion = 'Activo'

			select distinct
				trabajador,
				nombre,
				jefe2,
				(Select top 1
					nombre
				from RRHH.vw_datosTrabajadores W
				where W.codigo = T.jefe2) as NombreJefe2
			from @tabla6 T
			where jefe2Ant<> jefe2

          end
		  else if @tipo = 18
		  Begin

        declare @tablaTrab as table(trabajador char(10),
            d int)
        declare @tabla5 as table (compania char(4),
            trabajador char(10),
            nombre varchar(200),
            jefe1 varchar(80),
            jefe1Ant varchar(80))

        insert into @tablaTrab
        select trabajador, count(distinct Jefe1  )
        from rrhh.vw_datosTrabajadores
        where trabajador in ( select trabajador
            from adam.dbo.VW_TrabActivosmasUnaEmpresa) and Situacion = 'Activo'
        group by  Trabajador
        having count(distinct Jefe1  )>1

        insert into @tabla5
        select distinct '', trabajador, nombre, Jefe1 , ''
        from rrhh.vw_datosTrabajadores
        where trabajador in ( select trabajador
            from @tablaTrab)
            and Situacion = 'Activo'

        select distinct
            trabajador,
            nombre,
            jefe1,
            (Select top 1
                nombre
            from RRHH.vw_datosTrabajadores W
            where W.codigo = C.jefe1) as NombreJefe1
        from @tabla5 C

    end
		  else if @tipo = 19
		  begin

        INSERT INTO @tabla
        SELECT trabajador  
			, nombre  
			, cco  
			, Desc_CCO  
			, jefe1  
			, (  
				SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
				) AS nombre  
			, (  
				SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
				) AS cod_homologado  
			, CAR
        FROM RRHH.vw_datosTrabajadores C
        WHERE Situacion = 'Activo'
            AND car <> 'LOCALES'
            AND jefe1 IS NOT NULL
            AND clase_nomina IN ('11', '27')
            AND (  
				SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
				) > 70

        SELECT DISTINCT codigo   
							, nombre   
							, cargoHomologado
        FROM @tabla T
        WHERE cargoHomologado > 70


    end
		  else if @tipo = 20
		  begin
			INSERT INTO @tabla
			SELECT trabajador  
						, nombre  
						, cco  
						, Desc_CCO  
						, jefe2  
						, (  
							SELECT Nombre
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe2  
							) AS nombre  
						, (  
							SELECT cod_cargo_homologado
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe2  
							) AS cod_homologado  
						, CAR
			FROM RRHH.vw_datosTrabajadores C
			WHERE Situacion = 'Activo'
				AND car <> 'LOCALES'
				AND Jefe2 IS NOT NULL
				AND clase_nomina IN ('11', '27')
				AND (  
							SELECT cod_cargo_homologado
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe2  
							) > 70

			SELECT DISTINCT codigo  
					, nombre  
					, cargoHomologado
			FROM @tabla T
			WHERE cargoHomologado > 70

          end 
		  else if @tipo = 21
		  BEGIN

        INSERT INTO @tabla2
        SELECT trabajador  
				, nombre  
				, cco  
				, Desc_CCO  
				, jefe1  
				, (  
					SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
					) AS nombre  
				, (  
					SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
					) AS cod_homologado  
				, CAR
        FROM RRHH.vw_datosTrabajadores C
        WHERE Situacion = 'Activo'
            AND car <> 'LOCALES'
            AND eslocal = 'NO'
            AND jefe1 IS NOT NULL
            AND clase_nomina NOT IN ('11', '27')
            AND (  
				SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1  
				) > 60
        ---and cco in (select cc


        SELECT DISTINCT codigo   , nombre  , cargoHomologado
        FROM @tabla2 T
        WHERE cargoHomologado > 60
    end
		  Else if @tipo = 22
		  Begin
           INSERT INTO @tabla2
        SELECT trabajador  
					, nombre  
					, cco  
					, Desc_CCO  
					, jefe2  
					, (  
						SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) AS nombre  
					, (  
						SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) AS cod_homologado  
					, CAR
        FROM RRHH.vw_datosTrabajadores C
        WHERE Situacion = 'Activo'
            AND car <> 'LOCALES'
            AND Jefe2 IS NOT NULL
            AND clase_nomina NOT IN ('11', '27')
            AND (  
						SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) > 60
            AND eslocal = 'NO'

           SELECT DISTINCT codigo , nombre, cargoHomologado
        FROM @tabla2 T
        WHERE cargoHomologado > 60
          end
		  else if @tipo = 23
		  BEGIN
			INSERT INTO @tabla12
			SELECT cco  
					, descripcion  
					, jefe1  
					, (  
						SELECT Nombre
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe1  
						) AS nombre  
					, (  
						SELECT cod_cargo_homologado
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe1  
						) AS cod_homologado
			FROM Catalogos.centro_costos C
			WHERE esLocal = 'S'
				AND estatus = 1
				AND (  
						SELECT cod_cargo_homologado
				FROM RRHH.vw_datosTrabajadores
				WHERE codigo = C.jefe1  
						) > 50
				AND jefe1 IS NOT NULL

			INSERT INTO dbo.avisosTemporal
				(
				cco
				, descCCO
				, codigo
				, nombre
				, cargoHomologado
				, tipo
				)
			SELECT *  
					, 'A1'
			FROM @tabla12
			WHERE cargoHomologado > 50

			SELECT @w = count(*)
			FROM @tabla12
			WHERE cargoHomologado > 50

			SELECT DISTINCT codigo , nombre , cargoHomologado
			FROM @tabla12 T
			WHERE cargoHomologado > 50

	END
		  else if @tipo = 24
		  BEGIN
          INSERT INTO @tabla12
          SELECT cco  
					, descripcion  
					, jefe2  
					, (  
						SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) AS nombre  
					, (  
						SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) AS cod_homologado
        FROM Catalogos.centro_costos C
        WHERE esLocal = 'S'
            AND estatus = 1
            AND (  
						SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2  
						) > 50
            AND jefe2 IS NOT NULL


        SELECT DISTINCT codigo  , nombre  , CargoHomologado
        FROM @tabla12 T
        WHERE cargoHomologado > 50

    END
		  ELSE IF @tipo = 25
		  BEGIN
          DECLARE @tableCCOCargos AS TABLE (
            cco VARCHAR(15)  
		,
            descripcion VARCHAR(250)  
		,
            cargo VARCHAR(20)  
		)

          INSERT INTO @tableCCOCargos
        SELECT cco  
				, descripcion  
				, (  
					SELECT puesto
            FROM rrhh.vw_datosTrabajadores T
            WHERE T.codigo = C.jefe1  
			--and Puesto in ('0134', '0100', '0083', '0493', '0691')  
					)
        FROM catalogos.centro_costos C
        WHERE esLocal = 'S'
            AND estatus = 1

          SELECT DISTINCT cco    
						, descripcion   
						, cargo    
						, (  
							SELECT descripcion
            FROM Cargos.cargos C
            WHERE c.cod_cargo = T.cargo  
							)
        FROM @tableCCOCargos T
        WHERE cargo NOT IN (  
							SELECT valor
        FROM configuracion.parametros
        WHERE parametro = 'cargo_gteTienda'  
							)
 
          END
		  ELSE IF @tipo = 26
		  BEGIN 
           DECLARE @tableCCOCargos2 AS TABLE (
            cco VARCHAR(15)  
		,
            descripcion VARCHAR(250)  
		,
            cargo VARCHAR(20)  
		)

          INSERT INTO @tableCCOCargos2
        SELECT cco  
				, descripcion  
				, (  
					SELECT puesto
            FROM rrhh.vw_datosTrabajadores T
            WHERE T.codigo = C.jefe2 ---and Puesto in ('0134', '0100', '0083', '0493', '0691')  
					)
        FROM catalogos.centro_costos C
        WHERE esLocal = 'S'
            AND estatus = 1

           SELECT DISTINCT td = cco   
						, td = descripcion   
						, td = cargo   
						, td = (  
							SELECT descripcion
            FROM Cargos.cargos C
            WHERE c.cod_cargo = T.cargo  
							)
        FROM @tableCCOCargos2 T
        WHERE cargo NOT IN (  
							SELECT valor
        FROM configuracion.parametros
        WHERE parametro = 'cargo_gteTienda'  
							)

          END
		  ELSE IF @tipo = 27
		  Begin
          Select
            T.compania As Compania,
            T.Compania_Desc as Empresa,
            T.Clase_Nomina,
            T.Desc_Clase_Nomina,
            T.codigo as Codigo,
            T.nombre as Nombre,
            T.cco as CCO,
            T.Desc_CCO,
            T.cargo as Cargo,
            T.puesto as Puesto,
            C.jefesPyG,
            (Select ltrim(rtrim(descripcion))
            from Adam.dbo.datos_agr_trab A
            where agrupacion ='DIST_JEFAR' and A.dato = C.jefesPyG ) as Relacionada_Al_Trabajador ,
            (Select ltrim(rtrim(descripcion))
            from Adam.dbo.datos_agr_trab A
            where agrupacion ='DIST_JEFAR' and A.dato = R.dato ) as Pertenece_Al_Cargo
        from DB_NOMKFC.RRHH.vw_datosTrabajadores T inner join Adam.dbo.rel_trab_agr R
            on T.trabajador = R.trabajador and T.compania = R.compania
            inner join DB_NOMKFC.cargos.cargos C on C.cod_cargo = T.puesto
        where  agrupacion = 'DIST_JEFAR'
            and T.situacion = 'Activo'
            and C.jefesPyG<> R.dato
          End
		  ELSE IF @tipo = 28
		  BEGIN 
           SELECT T.compania, T.Compania_Desc, T.Clase_Nomina, T.Desc_Clase_Nomina,
            T.codigo,
            T.trabajador,
            T.nombre,
            T.cco,
            T.Desc_CCO,
            T.cargo,
            T.puesto,
            C.mano_obra,
            (
				SELECT LTRIM(RTRIM(descripcion))
            FROM Adam.dbo.datos_agr_trab A
            WHERE agrupacion = 'MO_DI_INDI'
                AND A.dato = C.mano_obra
			) AS DescManoObraCargo,
            LTRIM(RTRIM(R.dato)) AS manoObraRel,
            (
				SELECT LTRIM(RTRIM(descripcion))
            FROM Adam.dbo.datos_agr_trab A
            WHERE agrupacion = 'MO_DI_INDI'
                AND A.dato = R.dato
			) AS DescManoObraRelacionada
        FROM
            DB_NOMKFC.RRHH.vw_datosTrabajadores T
            INNER JOIN
            Adam.dbo.rel_trab_agr R
            ON T.trabajador = R.trabajador
                AND T.compania = R.compania
            INNER JOIN
            DB_NOMKFC.Cargos.rel_claseNomina_cargos C
            ON C.id_cargo = CONVERT(INT, T.puesto)
                AND C.id_clase_nomina = CONVERT(SMALLINT, T.Clase_Nomina)
        WHERE 
					R.agrupacion = 'MO_DI_INDI'
            AND T.situacion = 'Activo'
            AND C.mano_obra <> R.dato
			 
         END
		  ELSE IF @tipo = 29
		  Begin
          Select T.codigo, T.nombre, t.clase_nomina, T.cco, T.cargo, T.puesto,
            RC.car, (Select ltrim(rtrim(descripcion))
            from Adam.dbo.datos_agr_trab A
            where agrupacion ='CAR' and A.dato = RC.car ) as DescCARCargo ,
            R.dato, (Select ltrim(rtrim(descripcion))
            from Adam.dbo.datos_agr_trab A
            where agrupacion ='CAR' and A.dato = R.dato ) as DescjefesPyGRelacionada
        from db_NOMKFC.RRHH.vw_datosTrabajadores T inner join Adam.dbo.rel_trab_agr R
            on T.trabajador = R.trabajador and T.compania = R.compania
            inner join db_NOMKFC.cargos.cargos C on C.cod_cargo = T.puesto
            inner join db_NOMKFC.Cargos.rel_claseNomina_cargos RC on RC.id_cargo =  c.id_cargo and RC.id_clase_nomina = convert(smallint,T.clase_nomina)
        where  agrupacion = 'CAR'
            and T.situacion = 'Activo'
            and RC.car <> R.dato
          End
		  ELSE IF @tipo = 30
		  BEGIN
         
		  Select distinct clase_nomina, puesto, cargo  from RRHH.vw_datosTrabajadoresBasico t 
		   LEFT JOIN Cargos.rel_cargos_beneficios r ON convert(int,t.puesto) = r.id_cargo
		   and  convert (smallint, clase_nomina) = r.id_clase_nomina
		  where situacion = 'Activo'
		   AND r.id_cargo IS NULL
        END
		  ELSE IF @tipo = 31
		  BEGIN

        SELECT DISTINCT
            CONVERT(SMALLINT, t.clase_nomina) AS clase_nomina, cl.descripcion as cadena,
            t.Puesto  AS puesto, ca.descripcion as cargo
        FROM adam.dbo.fpv_datos_trabajador_nomina t
            LEFT JOIN Cargos.rel_claseNomina_cargos c
            ON CONVERT(INT, t.Puesto) = c.id_cargo
                AND CONVERT(SMALLINT, t.clase_nomina) = c.id_clase_nomina AND c.estado = 1
            Inner Join Cargos.cargos CA on ca.cod_cargo = puesto
            INNER JOIN catalogos.clases_de_nomina CL on cl.clase_nomina = t.clase_nomina
        WHERE t.situacion = 'Activo'
            AND c.id_cargo IS NULL
    END
		  ELSE IF @tipo = 32
		  BEGIN

        SELECT ca.cod_cargo, ca.descripcion AS cargo
        FROM Cargos.cargos ca
            LEFT JOIN adam.dbo.fpv_datos_trabajador_nomina t
            ON ca.cod_cargo = t.puesto AND t.situacion = 'Activo'
        WHERE t.puesto IS NULL
            and ca.estatus = 1


    END
End
 